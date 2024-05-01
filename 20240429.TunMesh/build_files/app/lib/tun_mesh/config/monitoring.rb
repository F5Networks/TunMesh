require_relative 'group'
require_relative 'monitoring/prometheus'
require_relative 'types/bool'
require_relative 'types/enum'
require_relative 'types/timing'

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

        add_field(
          Types::Bool.new(
            key: 'enable_node_packet_metrics',
            proto: key,
            default: false,
            description_short: 'Enable node level packet metrics.',
          )
        )

        add_field(
          Types::Timing.new(
            key: 'metric_ttl',
            proto: key,
            default: 3600,
            description_short: 'Metric TTL in seconds.',
            description_long: <<~EOF
              Maximum duration a metric will be presented at the /metrics endpoint without updates.
              Intended to allow dynamic labels, like remote IDs for detailed packet stats, without an ever-growing metric list.
            EOF
          )
        )

        add_field(Monitoring::Prometheus.new)
      end
    end
  end
end
