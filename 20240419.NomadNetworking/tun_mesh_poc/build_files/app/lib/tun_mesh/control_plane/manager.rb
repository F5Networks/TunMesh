require 'logger'
require 'securerandom'

require './lib/tun_mesh/config'
require './lib/tun_mesh/ipc/queue_manager'
require './lib/tun_mesh/vpn/router'
require_relative 'registrations'
require_relative 'structs/net_address'
require_relative 'structs/node_info'

module TunMesh
  module ControlPlane
    class Manager
      attr_reader :id, :queue_manager, :registrations, :self_node_info
      
      def initialize
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @id = SecureRandom.uuid

        @registrations = Registrations.new(manager: self)
        @self_node_info = Structs::NodeInfo.new(
          id: @id,
          listen_url: TunMesh::CONFIG.advertise_url,
          private_address: Structs::NetAddress.parse_cidr(TunMesh::CONFIG.private_address_cidr)
        )

        TunMesh::CONFIG.bootstrap_node_urls.each do |node_url|
          @registrations.bootstrap_node(remote_url: node_url)
        end

        @queue_manager = TunMesh::IPC::QueueManager.new(control: true)
        @router = TunMesh::VPN::Router.new(manager: self)

        @tx_queue = Queue.new
        @tx_workers = Hash.new { |h,k| h[k] = _new_tx_worker(id: k) }

        _worker_manager
      end

      def transmit_packet(**kwargs)
        @tx_queue.push(kwargs)
      end

      
      private

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
          @logger.warn("Dropping packet #{packet.md5}: Destination #{dest_addr} unknown")
          return
        end

        @logger.debug("Transmitting packet #{packet.md5} to #{remote_node.node_info.id} / #{dest_addr}")
        remote_node.transmit_packet(packet: packet)
      end
      
      def _worker_manager
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
              else
                @logger.debug("#{log_prefix}: Adding a worker")
                @tx_workers[SecureRandom.uuid]
              end
            elsif @tx_queue.num_waiting > 1
              sleeping_workers = @tx_workers.select { |_, t| t.status == "sleep" }
              if sleeping_workers.length < 1
                @logger.warn("#{log_prefix}: No sleeping thread to remove")
              else
                target = sleeping_workers.keys.sample
                @logger.debug("#{log_prefix}: Removing worker #{target}")
                @tx_workers.delete(target)
              end
            else
              @logger.debug(log_prefix)
            end

            # TODO: Hardcode / very slow
            sleep(5)
          end
        end
      end
    end
  end
end
