require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'

module TunMesh
  module ControlPlane
    class Registrations
      class BootstrapGroup
        def initialize(name:, registrations:)
          @name = name
          @registrations = registrations
          @logger = TunMesh::Logger.new(id: "#{self.class}(#{name})")

          @bootstrap_attempts = 0
          @last_bootstrap_attempt_stamp = 0

          @remote_node_ids = []
        end

        def bootstrapped?
          _groom

          return true if config.bootstrap_node_urls.empty?
          return true unless @remote_node_ids.empty?

          # NOTE: if we bootstrap successfully and then later groom all the remote nodes out of the node pool
          #  this will cause bootstrapping to be re-attempted.  Considering this a feature not a bug.
          return true if @bootstrap_attempts > config.bootstrap_retries && config.bootstrap_retries >= 0

          return false
        end

        def bootstrap!
          if (Time.now.to_i - @last_bootstrap_attempt_stamp) < TunMesh::CONFIG.values.process.timing.registrations.bootstrap_retry_interval
            @logger.debug { "Last attempt #{Time.now.to_i - @last_bootstrap_attempt_stamp}s / #{TunMesh::CONFIG.values.process.timing.registrations.bootstrap_retry_interval}s old: Skipping" }
            return nil
          end

          @last_bootstrap_attempt_stamp = Time.now.to_i
          @bootstrap_attempts += 1

          if config.bootstrap_retries < 0
            @logger.info { "Bootstrapping, attempt #{@bootstrap_attempts}" }
          else
            @logger.info { "Bootstrapping, attempt #{@bootstrap_attempts}/#{config.bootstrap_retries + 1}" }
          end

          config.bootstrap_node_urls.each do |node_url|
            remote_node = @registrations.bootstrap_node(remote_url: node_url)

            if remote_node
              @logger.info { "Bootstrap to #{node_url} successfully reached node #{remote_node.id}" }
              @remote_node_ids.push(remote_node.id)
            else
              @logger.warn("Bootstrap to #{node_url} failed")
            end
          end

          @logger.warn('Failed to bootstrap group') if @remote_node_ids.empty?
        end

        def config
          TunMesh::CONFIG.values.clustering.bootstrap_groups.fetch(@name)
        end

        private

        def _groom
          @remote_node_ids.delete_if { |remote_node_id| _groom_node(remote_node_id: remote_node_id) }
        end

        def _groom_node(remote_node_id:)
          remote_node = @registrations.node_by_id(remote_node_id)
          unless remote_node
            @logger.debug { "_groom_node(#{remote_node_id}): Not found" }
            return true
          end

          return false if remote_node.healthy?

          @logger.debug { "_groom_node(#{remote_node_id}): Unhealthy" }
          return true
        rescue StandardError => exc
          @logger.error("Failed to groom remote node #{remote_node_id}: #{exc.class}: #{exc}")
          @logger.debug { exc.backtrace }
          true
        end
      end
    end
  end
end
