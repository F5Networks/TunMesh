require 'logger'
require 'securerandom'

require './lib/tun_mesh/config'
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
        @logger = Logger.new(STDERR, level: TunMesh::CONFIG.values.logging.level, progname: self.class.to_s)

        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
        @registrations = Registrations.new(manager: self)
        @router = TunMesh::VPN::Router.new(manager: self, queue_manager: @queue_manager)
        @monitors = Monitoring.new(queue_manager: @queue_manager)
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
        monitors.increment_gauge(id: :remote_rx_packets)
        @router.rx_remote_packet(**kwargs)
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
    end
  end
end
