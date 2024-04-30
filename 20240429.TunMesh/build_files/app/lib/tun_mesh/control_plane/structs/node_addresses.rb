require './lib/tun_mesh/config/networking'
require_relative 'base'
require_relative 'net_address'

module TunMesh
  module ControlPlane
    module Structs
      # This class represents a set of addresses for the node
      class NodeAddresses < Base
        FIELDS = TunMesh::Config::Networking::SUPPORTED_PROTOCOLS.to_h do |proto|
          [proto,
           {
             type: NetAddress
           }]
        end
      end

      private

      # Extra validation, this struct is overloaded to enable other protocols without sprawling the structs
      def _set_attr(name, raw_value)
        raise('This is actually being called') # Test
        super(name, raw_value).validate_proto(name)
      end
    end
  end
end
