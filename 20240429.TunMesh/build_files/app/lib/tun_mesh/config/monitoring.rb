require_relative 'group'
require_relative 'monitoring/prometheus'
require_relative 'types/enum'

module TunMesh
  class Config
    class Monitoring < Group
      def initialize
        super(
          key: 'monitoring',
          description_short: 'Application monitoring configuration'
        )

        add_field(
          Types::Enum.new(
            key: 'method',
            default: 'none',
            description_short: 'Monitoring method to use.',
            allowed_values: {
              none: 'Disable monitoring',
              prometheus: 'Enable Prometheus metrics in the control API at /metrics'
            }
          )
        )
          
        add_field(Monitoring::Prometheus.new)
      end
    end
  end
end
