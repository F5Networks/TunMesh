require_relative '../../../group'
require_relative '../../../types/timing'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class Registrations < Group
          class RegistrationGroup < Group
            def initialize(**kwargs)
              super(**kwargs)

              add_field(
                Types::Timing.new(
                  key: 'reregistration_interval',
                  default: kwargs.fetch(:defaults).fetch(:reregistration_interval),
                  description_short: 'Interval at which to re-register to other cluster nodes',
                  description_long: 'Actual interval will be a multiple of groom_interval'
                )
              )

              add_field(
                Types::Timing.new(
                  key: 'stale_threshold',
                  default: kwargs.fetch(:defaults).fetch(:stale_threshold),
                  description_short: 'Threshold after which a remote node is marked as stale.',
                  description_long: <<~EOF
                    To be declared stale a remote node must not have re-registered to this node within stale_threshold seconds.
                    Once a remote node is marked stale it will be groomed out of the cluster and will stop receiving traffic.
                    Must be greater than reregistration_interval, ideally by a factor of at least 3.
                    Actual threshold will be a multiple of groom_interval
                  EOF
                )
              )
            end
          end
        end
      end
    end
  end
end
