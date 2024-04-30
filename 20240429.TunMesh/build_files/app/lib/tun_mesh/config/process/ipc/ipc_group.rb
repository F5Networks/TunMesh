require_relative '../../group'
require_relative '../../types/uint'

module TunMesh
  class Config
    class Process < Group
      class IPC < Group
        class IPCGroup < Group
          def initialize
            super(
              key: 'group',
              description_short: 'SysV queue (sysvipc(7)) settings'
            )

            add_field(
              Types::UInt.new(
                key: 'max_init_attempts',
                default: 3,
                description_short: 'Maximum number of attempts to initialize the queues',
                description_long: <<~EOF
                  The IPC handler will try up to max_init_attempts times to init the IPC queues, using a random key (See msgget(2)) each time.
                  Intended to allow the system to start on queue key collissions with other processes.
                  (Collissions are extremely unlikely as this app should be in a container with a unique IPC namespace.)
                EOF
              )
            )

            add_field(
              Types::UInt.new(
                key: 'key_range_min',
                base: 16,
                default: 0x80000000,
                description_short: 'Minimum value for the IPC queue keys',
                description_long: <<~EOF
                  Note that the lower 4 bits are reserved, so this value is masked with 0xfffffff0 to get the real value.
                  This process generates multiple queues, so queues will use the masked value + [0x00-0x0f] for the queue key.
                EOF
              )
            )

            add_field(
              Types::UInt.new(
                key: 'key_range_max',
                base: 16,
                default: 0x8ffffff0,
                description_short: 'Maximum value for the IPC queue keys',
                description_long: <<~EOF
                  Same restrictions as key_range_min
                  Set to key_range_min to pin the process to a fixed key base value.
                EOF
              )
            )
          end
        end
      end
    end
  end
end
