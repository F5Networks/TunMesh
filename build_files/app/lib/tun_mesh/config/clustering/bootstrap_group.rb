require_relative '../group'
require_relative '../types/list'
require_relative '../types/uint'
require_relative '../types/url'

module TunMesh
  class Config
    class Clustering < Group
      class BootstrapGroup < Group
        def initialize(**)
          super(
            key: 'bootstrap_url_group',
            description_short: 'Tun Mesh cluster Bootstrap URL Group'
          )

          add_field(
            Types::List.new(
              key: 'bootstrap_node_urls',
              allow_nil: true,
              allow_empty: true,
              value_type: Types::URL,
              description_short: 'List of URLs to register into on startup',
              description_long: <<~EOF
                This list is of the control_api_advertise_urls of other nodes in the cluster, and is used for initial bootstrapping new nodes into the cluster.
                This is normally only used on startup, once the node is registered into the cluster other nodes addresses are maintained by cluster IPC.
                This list does not need to be updated as the cluster nodes change.
                As long as new nodes register into any node of the existing cluster the new node address will automatically propagate back to existing nodes regardless of this setting.
                Intended to be generated through service discovery of the container platform.
                A load-balanced URL is also suitable if the platform supports load balancing.
                An empty list or nil value is allowed for the first node brought online, but subsequent must nodes must bootstrap into the node with the empty list for that node to join the cluster.
              EOF
            )
          )

          add_field(
            Types::Int.new(
              key: 'bootstrap_retries',
              default: -1,
              min: -1,
              description_short: 'Number of times to retry bootstrapping, when not joined to a cluster',
              description_long: <<~EOF
                If initial bootstrapping fails to register to any node, or if we fail to recieve inbound registrations, retry the bootstrap_node_urls list up to this many times.
                Delay between attempts is the tun_mesh/process/timing/registrations/bootstrap_retry_interval value.
                Note that when enabled the node will re-attempt bootstrapping if all the group nodes are groomed out of the pool.
                See also tun_mesh/process/timing/registrations/startup_grace to ensure the node initially passes healthchecks with no registrations.
                Set to 0 for only a single attempt.
                Set to -1 for infinite retries.
              EOF
            )
          )
        end
      end
    end
  end
end
