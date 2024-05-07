require_relative '../group'
require_relative 'timing/auth'
require_relative 'timing/registrations'
require_relative 'timing/network'
require_relative 'timing/tun_handler'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        def initialize
          super(
            key: 'timing',
            description_short: 'Timing: Process timing delays and values',
            description_long: <<~EOF
              All values are durations/intervals.
              Integer values are seconds.
              Suffixed values of the form [integer value][smhd] are supported, where s is seconds, m is minutes, h is hours, and d is days.
              Ranges of the form [min]..[max][suffix] are also supported, with the actual value being random between min and max, but note that the random value is calculated on config load, not at use.
            EOF
          )

          add_field(
            Types::Timing.new(
              key: 'request_timeout',
              default: 1.0,
              description_short: 'Cluster request timeout',
            )
          )

          add_field(Process::Timing::Auth.new)
          add_field(Process::Timing::Registrations.new)
          add_field(Process::Timing::Network.new)
          add_field(Process::Timing::TunHandler.new)
        end
      end
    end
  end
end
