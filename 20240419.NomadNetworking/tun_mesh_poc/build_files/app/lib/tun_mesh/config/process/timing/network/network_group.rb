require_relative '../../../group'
require_relative '../../../types/timing'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class Network < Group
          class NetworkGroup < Group
            def initialize(**kwargs)
              super(**kwargs)

              add_field(
                Types::Timing.new(
                  key: 'packet_expiration',
                  default: kwargs.fetch(:defaults).fetch(:packet_expiration),
                  description_short: 'Number of seconds after which a packet is marked stale and dropped',
                )
              )
            end
          end
        end
      end
    end
  end
end
