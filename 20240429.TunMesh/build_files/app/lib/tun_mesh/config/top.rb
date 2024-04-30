require_relative 'clustering'
require_relative 'control_api'
require_relative 'monitoring'
require_relative 'networking'
require_relative 'process'
require_relative 'types/uint'
require_relative 'version'

module TunMesh
  class Config
    # Top level config group of the conf file
    class Top < Group
      def initialize
        super(
          key: 'tun_mesh',
          description_short: 'Top level application config'
        )

        add_field(Version.new)
        add_field(Clustering.new)
        add_field(ControlAPI.new)
        add_field(Monitoring.new)
        add_field(Networking.new)
        add_field(Process.new)
      end

      def load_config_value(**kwargs)
        super
      rescue Errors::ParseError => exc
        exc.prefix_key(key: key)
        raise exc
      end
    end
  end
end
