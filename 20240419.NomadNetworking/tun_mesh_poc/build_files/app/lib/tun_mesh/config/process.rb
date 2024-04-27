require_relative 'group'
require_relative 'process/ipc'
require_relative 'process/timing'
require_relative 'types/uint'

module TunMesh
  class Config
    class Process < Group
      def initialize
        super(
          key: 'process',
          description_short: 'Settings unique to the tun_mesh process'
        )

        add_field(
          Types::UInt.new(
            key: 'uid',
            min: 1,
            description_short: 'Non-root user to de-escalate privileges to',
            description_long: 'Required: Running as root is not supported due to exposing a API on the network and the high initial privilege level needed to create the tunnel.'
          )
        )

        add_field(Process::IPC.new)
        add_field(Process::Timing.new)
      end
    end
  end
end
