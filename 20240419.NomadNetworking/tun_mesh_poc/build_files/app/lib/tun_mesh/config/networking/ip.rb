require_relative '../group'
require_relative '../types/net_address'

module TunMesh
  class Config
    class Networking < Group
      class IP < Group
        def initialize(key:)
          super(
            key: key,
            description_short: "#{key} Network Settings"
          )

          add_field(
            Types::NetAddress.new(
              key: 'network_cidr',
              proto: key,
              description_short: 'The overall network range to handle in CIDR notation.',
              description_long: <<EOF
This network must cover all IPs to be utilized in the mesh, all traffic to this cidr will be routed into the tunnel.
This setting is analagous to the VPC cidr in AWS: This sets the overall IP space available for use.
EOF
            )
          )

          add_field(
            Types::NetAddress.new(
              key: 'node_address_cidr',
              proto: key,
              description_short: 'The address of this host in CIDR notation.',
              description_long: <<EOF
The address is the unique address this node will use.  This address:
  - Must be within the network_cidr network
  - Must be unique within the network_cidr network.  Duplicates will cause routing problems.
The subnet prefix sets the broadcast range for the tunnel subnet.
Nodes within the network defined by node_address_cidr will receive broadcast traffic from other nodes in the subnet.
This subnet can be the same size or smaller as network_cidr.
EOF
            )
          )
        end
      end
    end
  end
end
          
