require 'logger'
require 'securerandom'

require './lib/tun_mesh/config'
require_relative 'registrations'
require_relative 'structs/net_address'
require_relative 'structs/node_info'

module TunMesh
  module ControlPlane
    class Manager
      attr_reader :id, :registrations, :self_node_info
      
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

        @router = TunMesh::VPN::Router.new(manager: self)
      end

      def transmit_packet(dest_addr:, packet:)
      end

      
      private
    end
    
  end
end
