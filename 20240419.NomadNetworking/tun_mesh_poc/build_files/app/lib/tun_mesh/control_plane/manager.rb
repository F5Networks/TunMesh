require 'logger'
require 'securerandom'

require './lib/tun_mesh/config'
require './lib/tun_mesh/vpn/router'
require_relative 'api'
require_relative 'registrations'
require_relative 'structs/net_address'
require_relative 'structs/node_info'

module TunMesh
  module ControlPlane
    class Manager
      attr_reader :api_auth, :registrations, :router, :self_node_info
      
      def initialize(queue_key:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)

        @registrations = Registrations.new(manager: self)
        @self_node_info = Structs::NodeInfo.new(
          id: TunMesh::CONFIG.node_id,
          listen_url: TunMesh::CONFIG.advertise_url,
          private_address: Structs::NetAddress.parse_cidr(TunMesh::CONFIG.private_address_cidr)
        )

        @router = TunMesh::VPN::Router.new(manager: self, queue_key: queue_key)
      end

      def api
        @api ||= API.new(manager: self)
      end
      
      def bootstrap!
        @logger.info("Bootstrapping into cluster")
        TunMesh::CONFIG.bootstrap_node_urls.each do |node_url|
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
        @router.rx_remote_packet(**kwargs)
      end

      def run_api!
        api.run! do
          # Only bootstrap once the API is up.
          # Otherwise it will fail as the other node calls back to us the check our ID
          bootstrap!
        end
      end
      
      def transmit_packet(dest_addr:, packet:)
        remote_node = @registrations.node_by_address(dest_addr)
        
        if remote_node.nil?
          @logger.warn { "TX: Dropping packet #{packet.id}: Destination #{dest_addr} unknown" }
          return
        end

        @logger.debug { "TX: Transmitting packet #{packet.id} to #{remote_node.node_info.id} / #{dest_addr}" }
        remote_node.transmit_packet(packet: packet)
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
