require_relative 'control_api/ssl'
require_relative 'group'
require_relative 'types/uint'

module TunMesh
  class Config
    class ControlAPI < Group
      def initialize
        super(
          key: 'control_api',
          description_short: 'Config for the control API Server'
        )

        add_field(
          Types::UInt.new(
            key: 'listen_port',
            default: 4567,
            description_short: 'Listening port for the API',
            description_long: 'This is the API bind port within the container, and is expected to be NATted by the container platform',
            max: 65535
          )
        )

        add_field(
          Types::UInt.new(
            key: 'max_batch_size',
            default: 64,
            description_short: 'Maximum number of VPN packets to send in a single API request',
            min: 1,
            max: 1024
          )
        )

        add_field(ControlAPI::SSL.new)
      end
    end
  end
end
