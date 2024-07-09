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
                  min: 0.01,
                  description_short: 'Number of seconds after which a packet is marked stale and dropped',
                  description_long: <<~EOF
                    This value should be below the TCP retry timout, which is 0.2s on current Linux servers.
                    https://pracucci.com/linux-tcp-rto-min-max-and-tcp-retries2.html
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
