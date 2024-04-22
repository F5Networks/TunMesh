require_relative 'base'
require_relative 'net_address'

module TunMesh
  module ControlPlane
    module Structs
      # This class represents the core attributes of a node
      class NodeInfo < Base
        FIELDS = {
          id: {
            type: String
          },
          
          listen_url: {
            type: String
          },
          
          private_address: {
            type: NetAddress
          }
        }
      end
    end
  end
end

    
