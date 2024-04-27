require_relative '../../group'
require_relative '../../types/timing'

module TunMesh
  class Config
    class Process < Group
      class Timing < Group
        class Auth < Group
          def initialize
            super(
              key: 'auth',
              description_short: 'Cluster authentication timing settings'
            )

            add_field(
              Types::Timing.new(
                key: 'early_validity_window',
                default: 5.0,
                description_short: 'Number of seconds before issue auth tokens will be valid.',
                description_long: 'Splay against clock drift between nodes in the cluster.'
              )
            )

            add_field(
              Types::Timing.new(
                key: 'validity_window',
                default: 30.0,
                description_short: 'Number of seconds from issue auth tokens will be valid',
                description_long: <<EOF
Must be long enough for processing, transport, and any acceptable clock drift between nodes in the cluster.
Note that this window is only for a single request, auth tokens are not reused.
EOF
              )
            )
          end
        end
      end
    end
  end
end
