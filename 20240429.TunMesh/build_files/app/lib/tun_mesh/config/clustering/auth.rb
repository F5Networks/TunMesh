require_relative '../group'
require_relative '../types/string'
require_relative '../types/uint'

module TunMesh
  class Config
    class Clustering < Group
      class Auth < Group
        def initialize
          super(
            key: 'auth',
            description_short: 'Cluster auth'
          )

          add_field(
            Types::String.new(
              key: 'secret',
              min_length: 32,
              description_short: 'Unique secret for the cluster',
              description_long: <<~EOF
                Shared secret to allow nodes to authenticate as allowed cluster nodes for registering into the cluster.
                32+ character, random string, unique to this cluster
              EOF
            )
          )

          add_field(
            Types::UInt.new(
              key: 'pub_key_size',
              default: 2048,
              min: 2048,
              description_short: 'Node public key length',
            )
          )
        end
      end
    end
  end
end
