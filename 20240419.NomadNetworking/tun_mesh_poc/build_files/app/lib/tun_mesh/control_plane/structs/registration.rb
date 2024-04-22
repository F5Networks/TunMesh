require_relative 'base'
require_relative 'node_info'

module TunMesh
  module ControlPlane
    module Structs
      # This class represents a registration between ndoes
      class Registration < Base
        FIELDS = {
          local: {
            type: NodeInfo
          },

          remote: {
            type: Array,
            val_type: NodeInfo
          },

          stamp: {
            type: Integer
          }
        } 
      end
    end
  end
end
