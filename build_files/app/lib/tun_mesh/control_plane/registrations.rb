require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'
require_relative 'structs/node_info'
require_relative 'structs/registration'
require_relative 'registrations/bootstrap_group'
require_relative 'registrations/errors'
require_relative 'registrations/fault_tracker'
require_relative 'registrations/remote_node_pool'

module TunMesh
  module ControlPlane
    class Registrations
      def initialize(manager:)
        @logger = TunMesh::Logger.new(id: self.class.to_s)
        @manager = manager

        @bootstrap_groups = Hash.new do |h, k|
          h[k] = BootstrapGroup.new(name: k, registrations: self)
        end

        @remote_nodes = RemoteNodePool.new(manager: @manager)
        @startup_grace_threshold = Time.now.to_f + TunMesh::CONFIG.values.process.timing.registrations.startup_grace

        @fault_trackers = Hash.new do |h, k|
          h[k] = FaultTracker.new(ttl: TunMesh::CONFIG.values.process.timing.registrations.groom_interval)
        end

        worker
      end

      def bootstrapped?
        return false if @bootstrap_groups.empty?

        return @bootstrap_groups.values.map(&:bootstrapped?).all?
      end

      def bootstrap!
        if TunMesh::CONFIG.values.clustering.reload_config_on_bootstrap
          @logger.debug('bootstrap!: Reloading config per config clustering.reload_config_on_bootstrap')
          TunMesh::CONFIG.parse_config! if TunMesh::CONFIG.values.clustering.reload_config_on_bootstrap
        end

        TunMesh::CONFIG.values.clustering.bootstrap_groups.each_key do |group_name|
          @bootstrap_groups[group_name].bootstrap! unless @bootstrap_groups[group_name].bootstrapped?
        rescue StandardError => exc
          @logger.error("Failed to bootstrap group #{group_name}: exception: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
          next
        end
      end

      def bootstrap_node(remote_url:, remote_node_id: nil)
        if remote_url == TunMesh::CONFIG.values.clustering.control_api_advertise_url.to_s
          @logger.debug("Skipping bootstrap to #{remote_url}: Self")
          return nil
        end

        if @fault_trackers[:bootstrap].blocked?(id: remote_url)
          @logger.debug("Bootstrap to #{remote_url} blocked by fault tracker")
          return nil
        end

        @logger.info("Bootstrapping remote node #{remote_node_id} at #{remote_url}")

        return @fault_trackers[:bootstrap].instrument(id: remote_url) do
          _register(api_client: @manager.api.new_client(remote_url: remote_url))
        end
      rescue StandardError => exc
        @logger.warn("Failed to bootstrap node at #{remote_url}: #{exc.class}: #{exc}")
        @logger.debug { exc.backtrace }
        return nil
      end

      def health
        {
          registered: _registered_health,
          worker: worker.alive?
        }
      end

      def healthy?
        health.values.all?
      end

      def outbound_registration_payload
        Structs::Registration.new(
          local: TunMesh::ControlPlane::Structs::NodeInfo.local,
          remote: @remote_nodes.nodes.map(&:node_info),
          stamp: Time.now.to_i
        )
      end

      def process_registration(raw_payload:, remote_node_id:, api_client: nil)
        registration = Structs::Registration.from_json(raw_payload)

        # Protection against misrouted discovery registrations
        # Could be due to a badly templated config block, or using a load balancer for discovery
        if registration.local.id == TunMesh::CONFIG.node_id
          @logger.warn('Rejecting registration from self')
          raise RegistrationFromSelf
        end

        if registration.local.id != remote_node_id
          @logger.warn("Rejecting registration with mismatched ID. #{registration.local.id} : #{remote_node_id}")
          raise RegistrationFailed
        end

        age = Time.now.to_i - registration.stamp
        if @remote_nodes.id?(registration.local.id)
          @logger.debug("Refreshed registration from #{registration.local.id} (#{age}s old)")
        else
          @logger.info("Received new registration from #{registration.local.id} (#{age}s old)")
        end

        return @remote_nodes.register(api_client: api_client, registration: registration)
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

            begin
              _groom
            rescue StandardError => exc
              @logger.error("Worker thread caught exception: #{exc.class}: #{exc}")
              @logger.debug(exc.backtrace)
            end
          end
        end
      end

      private

      def _groom
        begin
          bootstrap! unless bootstrapped?
        rescue StandardError => exc
          @logger.error("Failed to bootstrap: exception: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
        end

        if @remote_nodes.empty?
          @logger.warn('No remote nodes registered')
          return
        end

        @remote_nodes.ids.each do |id|
          _update_registration(id: id)
        rescue StandardError => exc
          @logger.error("Failed to groom remote node #{id}: exception: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
        end

        begin
          @remote_nodes.groom!
        rescue StandardError => exc
          @logger.error("Failed to groom remote_nodes: exception: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
        end

        begin
          @fault_trackers.values.each(&:groom)
        rescue StandardError => exc
          @logger.error("Failed to groom fault_trackers: exception: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
        end
      end

      def _register(api_client:)
        return process_registration(
          api_client: api_client,
          raw_payload: api_client.register(payload: outbound_registration_payload),
          remote_node_id: api_client.remote_id
        )
      end

      def _registered_health
        return true unless @remote_nodes.empty?
        return false if @startup_grace_threshold == :expired

        if @startup_grace_threshold > Time.now.to_f
          unless @startup_grace_announced
            @logger.warn("Startup grace: Returning healthy registration state for #{TunMesh::CONFIG.values.process.timing.registrations.startup_grace}s")
            @startup_grace_announced = true
          end

          return true
        end

        @logger.warn('Startup grace: Expired while unhealthy')
        @startup_grace_threshold = :expired
        return false
      end

      def _update_registration(id:)
        remote_node = node_by_id(id)
        raise(ArgumentError, "Unknown remote node #{id}") unless remote_node

        if remote_node.registration_required? && !@fault_trackers[:registration_update].blocked?(id: id)
          @logger.debug("Updating registration to #{id}")
          begin
            @fault_trackers[:registration_update].instrument(id: id) do
              _register(api_client: remote_node.api_client)
            end
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

          bootstrap_node(remote_node_id: remote_node_info.id, remote_url: remote_node_info.listen_url)
        end
      end
    end
  end
end
