require_relative 'api/client'
require_relative 'structs/registration'
require_relative 'registrations/errors'
require_relative 'registrations/remote_node'

module TunMesh
  module ControlPlane
    class Registrations
      def initialize(manager:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager
        
        @remote_nodes = {}
        @node_ids_by_address = {}
        @node_ids_by_address_lock = Mutex.new

        worker
      end

      def bootstrap_node(remote_url:)
        registration = _register(client: API::Client.new(manager: @manager, remote_url: remote_url))
        @remote_nodes[registration.local.id] = RemoteNode.new(manager: @manager, registration: registration)
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
            local: @manager.self_node_info,
            remote: @remote_nodes.values.map { |rn| rn.node_info },
            stamp: Time.now.to_i
        )
      end
      
      def process_registration(raw)
        registration = Structs::Registration.from_json(raw)

        # Protection against misrouted discovery registrations
        # Could be due to a badly templated config block, or using a load balancer for discovery
        raise RegistrationFromSelf if registration.local.id == @manager.id

        age = Time.now.to_i - registration.stamp
        @logger.info("Received registration from #{registration.local.id} (#{age}s old)")
        _store_registration(registration: registration)

        return registration
      end

      def nodes_by_address
        return @nodes_by_address if @nodes_by_address

        @node_ids_by_address_lock.synchronize do
          @logger.debug("Regenerating nodes_by_address map")
          @nodes_by_address = @node_ids_by_address.transform_values { |node_id| @remote_nodes[node_id] }.reject { |_, v| v.nil? }
        end

        return @nodes_by_address
      end

      def to_json(*args, **kwargs)
        @remote_nodes.to_json(*args, **kwargs)
      end

      def worker
        @worker = nil unless @worker&.alive?
        @worker ||= Thread.new do
          loop do
            # TODO: Hardcode / slow
            sleep(5)
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

        # NOTE: each_key *NOT* safe here
        @remote_nodes.keys.each { |id| _update_registration(id: id) }

        @remote_nodes.delete_if do |node_id, node|
          if node.stale?
            @logger.warn("Removed stale node #{node_id}")
            node.close
            true
          elsif node.healthy?
            false
          else
            @logger.warn("Removed unhealthy node #{node_id}: #{node.health}")
            node.close
            true
          end
        end
      end

      def _register(client:)
        resp = client.register(payload: outbound_registration_payload)
        return process_registration(resp)
      end

      def _store_registration(registration:)
        if @remote_nodes.key?(registration.local.id)
          @remote_nodes[registration.local.id].update_registration(registration)
        else
          @remote_nodes[registration.local.id] = RemoteNode.new(manager: @manager, registration: registration)
        end

        private_address = @remote_nodes[registration.local.id].node_info.private_address.address
        @node_ids_by_address_lock.synchronize do
          if @node_ids_by_address.key?(private_address)
            return if @node_ids_by_address[private_address] == registration.local.id

            @logger.warn("Replacing node #{@node_ids_by_address[private_address]} with #{registration.local.id} for #{private_address}")
            @remote_nodes[@node_ids_by_address[private_address]]&.close
          else
            @logger.info("Storing node #{registration.local.id} for #{private_address}")
          end

          @node_ids_by_address[private_address] = registration.local.id
          @nodes_by_address = nil
        end
      end

      def _update_registration(id:)
        raise(ArgumentError, "Unknown remote node #{id}") unless @remote_nodes.key?(id)
        
        remote_node = @remote_nodes[id]
      
        if remote_node.registration_required?
          @logger.info("Updating registration to #{id}")
          begin
            _register(client: remote_node.client)
          rescue StandardError => exc
            @logger.warn("Failed to register to node #{id}: #{exc.class}: #{exc}")
            return
          end
        end

        remote_node.remotes.each do |remote_node_info|
          next if remote_node_info.id == @manager.id
          # If the node is in the @remote_nodes list it will be handled by the outer loop
          next @remote_nodes.key?(remote_node_info.id)

          @logger.info("Bootstrapping remote node #{remote_node_info.id} at #{remote_node_info.listen_url}, via #{id}")
          bootstrap_node(remote_url: remote_node_info.listen_url)
        end
      end
    end
  end
end
