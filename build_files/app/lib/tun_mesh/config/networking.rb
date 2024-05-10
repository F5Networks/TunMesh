require_relative 'networking/ip'
require_relative 'group'
require_relative 'types/string'

module TunMesh
  class Config
    class Networking < Group
      # List of supported protocols, used in building address structs
      SUPPORTED_PROTOCOLS = %i[ipv4].freeze

      def initialize
        super(
          key: 'networking',
          description_short: 'Tun Mesh cluster settings'
        )

        add_field(Networking::IP.new(key: 'ipv4'))
        add_field(
          Types::String.new(
            key: 'tun_device_id',
            default: 'tun1',
            description_short: 'Device ID of the tun device to create in the container'
          )
        )
      end
    end
  end
end
