require_relative '../../group'
require_relative '../../types/timing'
require_relative 'registrations/registration_group'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class Registrations < Group
          def initialize
            super(
              key: 'registrations',
              description_short: 'Cluster registration timing'
            )

            add_field(
              Types::Timing.new(
                key: 'groom_interval',
                default: 5.0,
                description_short: 'Delay between grooming the remote node list',
                description_long: <<~EOF
                  Grooming entails:
                   - Updating registrations to other nodes
                   - Removing stale / unhealthy remote node data
                  Longer intervals will result in propagation delays of node/address changes in the cluster.
                EOF
              )
            )

            add_field(
              Types::Timing.new(
                key: 'startup_grace',
                default: 0,
                description_short: 'Amount of time after startup that the registrations health check will pass, regardless of registration state.',
                description_long: 'Intended to allow new nodes to enter the service discovery pool so that new new clusters can bootstrap.'
              )
            )

            add_field(
              RegistrationGroup.new(
                key: 'local',
                description_short: 'Timing values related to registrations to nodes within the same local subnet',
                defaults: {
                  reregistration_interval: 5.0,
                  stale_threshold: 30.0
                }
              )
            )

            add_field(
              RegistrationGroup.new(
                key: 'mesh',
                description_short: 'Timing values related to registrations to nodes within the mesh but outside the same local subnet.',
                defaults: {
                  reregistration_interval: 30.0,
                  stale_threshold: 120.0
                }
              )
            )
          end
        end
      end
    end
  end
end
