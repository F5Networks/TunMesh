require 'pathname'
require 'securerandom'

require './lib/tun_mesh/logger'
require './lib/tun_mesh/vpn/router'
require_relative 'api'
require_relative 'monitoring'
require_relative 'registrations'
require_relative 'structs/net_address'
require_relative 'structs/node_info'

module TunMesh
  module ControlPlane
    class Manager
      attr_reader :api_auth, :monitors, :registrations, :router

      def initialize(queue_key:)
        @logger = TunMesh::Logger.new(id: self.class.to_s)

        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
        @registrations = Registrations.new(manager: self)
        @router = TunMesh::VPN::Router.new(manager: self, queue_manager: @queue_manager)
        @monitors = Monitoring.new(queue_manager: @queue_manager)

        _log_build_info
      end

      def api
        @api ||= API.new(manager: self)
      end

      def health
        _health_sub_targets.transform_values(&:health)
      end

      def healthy?
        return _health_sub_targets.transform_values(&:healthy?).values.all?
      end

      def receive_packet(**kwargs)
        @router.rx_remote_packet(**kwargs)
      rescue StandardError
        @logger.warn("Failed to process packet from #{source}: #{exc.class}: #{exc}")
        @logger.debug { exc.backtrace }
        monitors.increment_gauge(id: :dropped_packets, labels: { reason: :exception })
      end

      def receive_packet_batch(batch_json:, source:)
        # batch_json is a JSON array of JSON encoded packets because, frankly, the nesting makes this part easy.
        packets = JSON.parse(batch_json)
        @logger.debug { "Processing #{packets.length} batch from #{source}" }
        packets.each.with_index do |payload, index|
          begin
            @router.rx_remote_packet(packet_json: payload, source: source)
          rescue StandardError
            @logger.warn("Failed to process packet #{index + 1} / #{packets.length} from #{source}: #{exc.class}: #{exc}")
            @logger.debug { exc.backtrace }
            monitors.increment_gauge(id: :dropped_packets, labels: { reason: :exception })
          end
        end
      end

      def run_api!
        api.run!
      end

      private

      def _health_sub_targets
        return {
          monitoring: @monitors,
          registrations: @registrations,
          router: @router
        }
      end

      def _log_build_info
        info_file = Pathname.new('/app/build_info.txt') # Generated in the Dockerfile
        if info_file.file?
          @logger.info("Tun Mesh: #{info_file.read.strip}")
        else
          @logger.warn("Build info file #{info_file} missing!")
        end
      end
    end
  end
end
