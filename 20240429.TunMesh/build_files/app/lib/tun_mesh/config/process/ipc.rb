require_relative '../group'
require_relative 'ipc/ipc_group'

module TunMesh
  class Config
    class Process < Group
      class IPC < Group
        def initialize
          super(
            key: 'ipc',
            description_short: 'Internal process IPC settings',
            description_long: <<EOF
This app forks subprocesses for parallel processing and separation of tasks.
IPC is via SysV APIs.
IPC is internal to the app, so no special container level IPC settings are required.
EOF
          )

          add_field(Process::IPC::IPCGroup.new)
        end
      end
    end
  end
end
