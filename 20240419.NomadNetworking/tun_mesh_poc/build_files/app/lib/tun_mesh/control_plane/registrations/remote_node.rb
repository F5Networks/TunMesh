require_relative '../api_client'
require_relative '../structs/registration'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNode
        attr_reader :registration
        
        def initialize(registration:)
          @registration = registration
        end

        def client
          @client ||= APIClient.new(remote_url: registration.local.listen_url)
        end

        def node_info
          @registration.local
        end
        
        def registration_required?
          # TODO: Hardcode
          (Time.now.to_i - stamp) > 5
        end

        def remotes
          @registration.remote
        end
        
        def stale?
          # TODO: Hardcode
          (Time.now.to_i - stamp) > 30
        end
        
        def stamp
          registration.stamp
        end

        def update_registration(new_registration)
          raise(ArgumentError, "new_registration not a Structs::Registration, got #{new_registration.class}") unless new_registration.is_a?(Structs::Registration)
          raise("ID Mismatch #{registration.local.id} / #{new_registration.local.id}") if registration.local.id != new_registration.local.id

          @client = nil
          @registration = new_registration
        end
      end
    end
  end
end
          
          
