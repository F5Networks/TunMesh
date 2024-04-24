require 'logger'
require 'securerandom'

require './lib/tun_mesh/config'
require './lib/tun_mesh/vpn/router'
require_relative 'api/server'
require_relative 'auth'
require_relative 'registrations'
require_relative 'structs/net_address'
require_relative 'structs/node_info'

module TunMesh
  module ControlPlane
    class Manager
      attr_reader :api_auth, :id, :registrations, :router, :self_node_info
      
      def initialize(queue_key:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @id = SecureRandom.uuid

        @api_auth = Auth.new(manager: self, secret: TunMesh::CONFIG.control_auth_secret)
        @registrations = Registrations.new(manager: self)
        @self_node_info = Structs::NodeInfo.new(
          id: @id,
          listen_url: TunMesh::CONFIG.advertise_url,
          private_address: Structs::NetAddress.parse_cidr(TunMesh::CONFIG.private_address_cidr)
        )

        TunMesh::CONFIG.bootstrap_node_urls.each do |node_url|
          @registrations.bootstrap_node(remote_url: node_url)
        end

        @router = TunMesh::VPN::Router.new(manager: self, queue_key: queue_key)

        @tx_queue = Queue.new
        @tx_workers = Hash.new { |h,k| h[k] = _new_tx_worker(id: k) }
        @worker_pool_healthy = false

        _worker_manager
      end

      def health
        _health_sub_targets.transform_values(&:health).merge({manager: _health})
      end
      
      def healthy?
        return false unless _health.values.all?
        return _health_sub_targets.transform_values(&:healthy?).values.all?
      end
      
      def receive_packet(**kwargs)
        @router.rx_remote_packet(**kwargs)
      end

      def run_api!
        API::Server.run!(
          manager: self
        )
      end
      
      def transmit_packet(**kwargs)
        @tx_queue.push(kwargs)
      end

      private

      def _health
        return {
          worker_pool_manager: _worker_manager.alive?,
          worker_pool: @worker_pool_healthy
        }
      end

      def _health_sub_targets
        return {
          registrations: @registrations,
          router: @router
        }
      end

      def _new_tx_worker(id:)
        Thread.new do
          @logger.debug("TXWorker(#{id}): Initialized")

          loop do
            work = @tx_queue.pop
            break if work.nil?

            _transmit_packet(**work)
            @logger.debug("TXWorker(#{id}): Iterating")

            break unless @tx_workers.key?(id)
          end

          @logger.debug("TXWorker(#{id}): Exiting")
        end
      end
    
      def _transmit_packet(dest_addr:, packet:)
        remote_node = @registrations.nodes_by_address[dest_addr]
        
        if remote_node.nil?
          @logger.warn { "Dropping packet #{packet.id}: Destination #{dest_addr} unknown" }
          return
        end

        @logger.debug { "Transmitting packet #{packet.id} to #{remote_node.node_info.id} / #{dest_addr}" }
        remote_node.transmit_packet(packet: packet)
      end
      
      def _worker_manager
        @worker_manager = nil unless @worker_manager&.alive?
        @worker_manager ||= Thread.new do
          desired_workers = 0
          loop do
            @tx_workers.delete_if { |_, v| !v.alive? }

            idle_workers = @tx_queue.num_waiting
            sleeping_workers = @tx_workers.select { |_, t| t.status == "sleep" }
            log_prefix = "WorkerManager: #{@tx_queue.size} pending messages / #{idle_workers} idle workers / #{@tx_workers.length} total threads / #{sleeping_workers.length} sleeping threads"
            if @tx_queue.num_waiting < 1
              # TODO: hardcode
              if @tx_workers.length > 10
                @logger.warn("#{log_prefix}: Max threads reached")
                @worker_pool_healthy = false
              else
                @logger.debug("#{log_prefix}: Adding a worker")
                @tx_workers[SecureRandom.uuid]
                @worker_pool_healthy = true
              end
            elsif @tx_queue.num_waiting > 1
              sleeping_workers = @tx_workers.select { |_, t| t.status == "sleep" }
              if sleeping_workers.length < 1
                @logger.warn("#{log_prefix}: No sleeping thread to remove")
                @worker_pool_healthy = false
              else
                target = sleeping_workers.keys.sample
                @logger.debug("#{log_prefix}: Removing worker #{target}")
                @tx_workers.delete(target)
                @worker_pool_healthy = true
              end
            else
              @logger.debug(log_prefix)
              @worker_pool_healthy = true
            end

            # TODO: Hardcode / very slow
            sleep(5)
          end
        end
      end
    end
  end
end
