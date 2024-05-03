require_relative 'clustering/auth'
require_relative 'group'
require_relative 'types/list'
require_relative 'types/uint'
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
              The control API of this node must be accessible from all other nodes at this URL over the external network.
              Must be a URL unique to this node, the advertise URL cannot be load balanced with other nodes.
              Intended to be built with the network container external IP and NATed API port via the container platform.
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
          Types::UInt.new(
            key: 'bootstrap_retries',
            default: 0,
            description_short: 'Number of times to retry bootstrapping, when not joined to a cluster',
            description_long: <<~EOF
              If initial bootstrapping fails to register to any node, or if we fail to recieve inbound registrations, retry the bootstrap_node_urls list up to this many times.
              Delay between attempts is the tun_mesh/process/timing/registrations/bootstrap_retry_interval value.
              Intended as a mitigation for badly behaved orchestration platforms, this allows bootstrapping through a load balancer if the orchestration platform does not allow service discovery or proper templating of bootstrap_node_urls.
              Note that when enabled the node will re-attempt bootstrapping if all the nodes are groomed out of the pool.
              See also tun_mesh/process/timing/registrations/startup_grace to ensure the node initially passes healthchecks with no registrations.
            EOF
          )
        )

        add_field(
          Types::Bool.new(
            key: 'reload_config_on_bootstrap',
            default: false,
            description_short: 'Reload the config file when bootstrapping',
            description_long: <<~EOF
              When true the config file will be reloaded before attempting bootstrapping.
              Intended for use with bootstrap_retries.
            EOF
          )
        )
      end
    end
  end
end
