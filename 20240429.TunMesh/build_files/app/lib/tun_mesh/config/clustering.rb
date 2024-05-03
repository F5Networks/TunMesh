require_relative 'clustering/auth'
require_relative 'group'
require_relative 'types/list'
require_relative 'types/url'

module TunMesh
  class Config
    class Clustering < Group
      def initialize
        super(
          key: 'clustering',
          description_short: 'Tun Mesh cluster settings'
        )

        add_field(
          Types::URL.new(
            key: 'control_api_advertise_url',
            description_short: 'External URL to advertise to other cluster nodes',
            description_long: <<~EOF
              The control API of this node must be accessible from all other nodes at this URL over the external network
              Intended to be built with the network container external IP and NATed API port via the container platform
            EOF
          )
        )

        add_field(Clustering::Auth.new)
        add_field(
          Types::List.new(
            key: 'bootstrap_node_urls',
            allow_nil: true,
            allow_empty: true,
            value_type: Types::URL,
            description_short: 'List of URLs to register into on startup',
            description_long: <<~EOF
              This list is of the control_api_advertise_urls of other nodes in the cluster, and is used for initial bootstrapping new nodes into the cluster.
              This is only used on startup, once the node is registered into the cluster other nodes addresses are maintained by cluster IPC.
              This list does not need to be updated as the cluster nodes change.
              As long as new nodes register into any node of the existing cluster the new node address will automatically propagate back to existing nodes regardless of this setting.
              Intended to be generated through service discovery of the container platform.
              A load-balanced URL is also suitable if the platform supports load balancing.
              An empty list or nil value is allowed for the first node brought online, but subsequent must nodes must bootstrap into the node with the empty list for that node to join the cluster.
            EOF
          )
        )
      end
    end
  end
end
