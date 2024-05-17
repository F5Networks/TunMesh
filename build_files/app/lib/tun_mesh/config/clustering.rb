require_relative 'clustering/auth'
require_relative 'clustering/bootstrap_group'
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
          Types::Hash.new(
            key: 'bootstrap_groups',
            required: true,
            value_type: Clustering::BootstrapGroup,
            example_value: {
              default: Clustering::BootstrapGroup.new
            },
            description_short: 'Map of Bootstrap configs',
            description_long: <<~EOF
              Multiple groups are supported to allow local and remote bootstrap URLs with different settings.
              Map key is a unique name for identification / logging.
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
              Removal of groups on reload is not supported.
            EOF
          )
        )
      end
    end
  end
end
