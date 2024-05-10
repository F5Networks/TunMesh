require_relative '../../group'
require_relative '../../types/timing'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class TunHandler < Group
          def initialize
            super(
              key: 'tun_handler',
              description_short: 'Timing unique to the tunnel handler process',
              description_long: 'These settings are highly internal, do not impact external behavior, and should not need to be tuned.'
            )

            add_field(
              Types::Timing.new(
                key: 'heartbeat_interval',
                default: 1.0,
                description_short: 'Frequency with which the tunnel handler process heartbeats to the control process.',
                description_long: 'Longer intervals will result in delays detecting internal faults.'
              )
            )

            add_field(
              Types::Timing.new(
                key: 'fault_delay',
                default: 1.0,
                description_short: 'Busy-loop delay on tunnel faults',
                description_long: 'This is a protection against internal faults fast-looping'
              )
            )
          end
        end
      end
    end
  end
end
