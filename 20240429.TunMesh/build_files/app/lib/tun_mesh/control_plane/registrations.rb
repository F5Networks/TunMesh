require './lib/tun_mesh/config'
require_relative 'structs/node_info'
require_relative 'structs/registration'
require_relative 'registrations/errors'
require_relative 'registrations/remote_node_pool'

module TunMesh
  module ControlPlane
    class Registrations
      def initialize(manager:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager

        @remote_nodes = RemoteNodePool.new(manager: @manager)

        worker
      end

      def bootstrap_node(remote_url:)
        _register(api_client: @manager.api.new_client(remote_url: remote_url))
      rescue StandardError => exc
        @logger.warn("Failed to bootstrap node at #{remote_url}: #{exc.class}: #{exc}")
        @logger.debug { exc.backtrace }
      end

      def health
        {
          registered: !@remote_nodes.empty?,
          worker: worker.alive?,
        }
      end

      def healthy?
        health.values.all?
      end

      def outbound_registration_payload
        Structs::Registration.new(
          local: TunMesh::ControlPlane::Structs::NodeInfo.local,
          remote: @remote_nodes.nodes.map { |rn| rn.node_info },
          stamp: Time.now.to_i
        )
      end

      def process_registration(raw_payload:, remote_node_id:, api_client: nil)
        registration = Structs::Registration.from_json(raw_payload)

        # Protection against misrouted discovery registrations
        # Could be due to a badly templated config block, or using a load balancer for discovery
        if registration.local.id == TunMesh::CONFIG.node_id
          @logger.warn("Rejecting registration from self")
          raise RegistrationFromSelf
        end

        if registration.local.id != remote_node_id
          @logger.warn("Rejecting registration with mismatched ID. #{registration.local.id} : #{remote_node_id}")
          raise RegistrationFailed
        end

        age = Time.now.to_i - registration.stamp
        @logger.info("Received registration from #{registration.local.id} (#{age}s old)")
        @remote_nodes.register(api_client: api_client, registration: registration)

        return registration
      end

      def node_by_address(**kwargs)
        @remote_nodes.node_by_address(**kwargs)
      end

      def node_by_id(id)
        @remote_nodes.node_by_id(id)
      end

      def nodes_by_proto(**kwargs)
        @remote_nodes.nodes_by_proto(**kwargs)
      end

      def to_json(*args, **kwargs)
        @remote_nodes.to_json(*args, **kwargs)
      end

      def worker
        @worker = nil unless @worker&.alive?
        @worker ||= Thread.new do
          loop do
            sleep(TunMesh::CONFIG.values.process.timing.registrations.groom_interval)
            _groom
          end
        end
      end

      private

      def _groom
        if @remote_nodes.empty?
          @logger.warn("No remote nodes registered")
          return
        end

        @remote_nodes.ids.each do |id|
          # Ensure nodes have session auth
          @remote_nodes.node_by_id(id).api_client.groom_auth

          _update_registration(id: id)
        end
        @remote_nodes.groom!
      end

      def _register(api_client:)
        return process_registration(
                 api_client: api_client,
                 raw_payload: api_client.register(payload: outbound_registration_payload),
                 remote_node_id: api_client.remote_id
               )
      end

      def _update_registration(id:)
        remote_node = node_by_id(id)
        raise(ArgumentError, "Unknown remote node #{id}") unless remote_node

        if remote_node.registration_required?
          @logger.info("Updating registration to #{id}")
          begin
            _register(api_client: remote_node.api_client)
          rescue StandardError => exc
            @logger.warn("Failed to register to node #{id}: #{exc.class}: #{exc}")
            @logger.debug { exc.backtrace }
            return
          end
        end

        remote_node.remotes.each do |remote_node_info|
          next if remote_node_info.id == TunMesh::CONFIG.node_id
          # If the node is in the @remote_nodes list it will be handled by the outer loop
          next if @remote_nodes.node_by_id(remote_node_info.id)

          @logger.info("Bootstrapping remote node #{remote_node_info.id} at #{remote_node_info.listen_url}, via #{id}")
          bootstrap_node(remote_url: remote_node_info.listen_url)
        end
      end
    end
  end
end
