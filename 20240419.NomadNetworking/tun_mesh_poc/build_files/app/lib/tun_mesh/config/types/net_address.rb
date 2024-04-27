require './lib/tun_mesh/control_plane/structs/net_address'
require_relative 'base'

module TunMesh
  class Config
    module Types
      class NetAddress < Base
        def initialize(proto:, **kwargs)
          super(**kwargs)
          @proto = proto
        end
        
        def load_config_value(value:, **)
          @value = TunMesh::ControlPlane::Structs::NetAddress.parse_cidr(value)
          @value.validate_proto(@proto)
        end
      end
    end
  end
end
