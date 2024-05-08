require './lib/tun_mesh/config'
require_relative 'base'
require_relative 'node_addresses'

module TunMesh
  module ControlPlane
    module Structs
      # This class represents the core attributes of a node
      class NodeInfo < Base
        FIELDS = {
          id: {
            type: String
          },

          listen_url: {
            type: String
          },

          network_addresses: {
            type: NodeAddresses
          },

          node_addresses: {
            type: NodeAddresses
          }
        }.freeze

        def self.local
          return @local ||= new(
            id: TunMesh::CONFIG.node_id,
            listen_url: TunMesh::CONFIG.values.clustering.control_api_advertise_url.to_s,
            network_addresses: NodeAddresses.new(
              **NodeAddresses::FIELDS.keys.to_h do |proto|
                [proto, TunMesh::CONFIG.values.networking[proto].network_cidr]
              end
            ),

            node_addresses: NodeAddresses.new(
              **NodeAddresses::FIELDS.keys.to_h do |proto|
                [proto, TunMesh::CONFIG.values.networking[proto].node_address_cidr]
              end
            )
          )
        end
      end
    end
  end
end
