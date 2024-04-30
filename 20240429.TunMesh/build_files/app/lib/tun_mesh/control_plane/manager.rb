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
        @logger = Logger.new(STDERR, progname: self.class.to_s)

        @registrations = Registrations.new(manager: self)
        @router = TunMesh::VPN::Router.new(manager: self, queue_key: queue_key)
        @monitors = Monitoring.new
      end

      def api
        @api ||= API.new(manager: self)
      end

      def bootstrap!
        @logger.info('Bootstrapping into cluster')
        TunMesh::CONFIG.values.clustering.bootstrap_node_urls.each do |node_url|
          @registrations.bootstrap_node(remote_url: node_url)
        end
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
        api.run! do
          # Only bootstrap once the API is up.
          # Otherwise it will fail as the other node calls back to us the check our ID
          bootstrap!
        end
      end

      private

      def _health_sub_targets
        return {
          registrations: @registrations,
          router: @router
        }
      end
    end
  end
end
