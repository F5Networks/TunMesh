require_relative '../../group'
require_relative 'network/network_group'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class Network < Group
          def initialize
            super(
              key: 'network',
              description_short: 'Network timing settings'
            )

            add_field(
              NetworkGroup.new(
                key: 'local',
                description_short: 'Timing values related to local subnet networking.',
                defaults: {
                  packet_expiration: 0.1
                }
              )
            )

            add_field(
              NetworkGroup.new(
                key: 'mesh',
                description_short: 'Timing values related to networking outside the local subnet.',
                defaults: {
                  packet_expiration: 0.1
                }
              )
            )
          end
        end
      end
    end
  end
end
