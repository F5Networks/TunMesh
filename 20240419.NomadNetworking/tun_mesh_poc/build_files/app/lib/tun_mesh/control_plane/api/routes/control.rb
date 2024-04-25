require 'sinatra/extension'
require 'sinatra/json'

module TunMesh
  module ControlPlane
    module API
      module Routes
        module Control
          extend Sinatra::Extension
          
          # Args are passed in via Sinatra .set in TunMesh::ControlPlane::API::Server.run!
          # This const defines the args this route needs.
          REQUIRED_ARGS = %i[manager].freeze

          get '/tunmesh/control/v0/node_info/id' do
            # No inbound auth, as this endpoint is intended for use when the other end doesn't know
            #   our ID (Bootstrapping by URL only) and as such can't set the aud claim.
            # Our ID isn't secret, so rather than add a exception to the Auth class just add this endpoint.
            #
            # No return auth, as that could be used to crack the cluster shared secret, which is the weakest and not auto-rotated.
            json({id: settings.manager.id})
          end

          post '/tunmesh/control/v0/packet/rx' do
            return unless Control._ensure_json_content(context: self)

            body = request.body.read
            return unless Control._ensure_rx_auth(body: body, context: self)

            settings.manager.receive_packet(packet_json: body)
            status 204
          end

          get '/tunmesh/control/v0/registrations' do
            json settings.manager.registrations
          end

          post '/tunmesh/control/v0/registrations/register' do
            return unless Control._ensure_json_content(context: self)
            begin
              body = request.body.read
              Control._ensure_mutual_auth(body: body, context: self) do |remote_node_id|
                settings.manager.registrations.process_registration(raw_payload: body, remote_node_id: remote_node_id)

                # Respond with our own info, to allow for a two way sync
                settings.manager.registrations.outbound_registration_payload
              end
            rescue TunMesh::ControlPlane::Registrations::RegistrationFromSelf
              status 421
              body "Registration to self"
            rescue TunMesh::ControlPlane::Registrations::RegistrationFailed
              status 400
              body "Failed"              
            end
          end
          
          get '/tunmesh/control/v0/registrations/routes' do
            # TODO: Name
            json settings.manager.registrations.nodes_by_address
          end

          post '/tunmesh/control/v0/sessions/initiate' do
            
            
          end
          
          private

          def self._ensure_mutual_auth(body:, context:)
            remote_node_id = self._ensure_rx_auth(body: body, context: context)
            return if remote_node_id.nil?

            payload = yield(remote_node_id).to_json

            context.response.headers['Authorization'] = context.settings.manager.api_auth.new_http_authorization_header_value(payload: payload, remote_node_id:)
            context.status(200)
            # Not using the JSON extension here as the body and auth payload must match
            context.content_type('application/json')
            context.body(payload)
          end

          def self._ensure_rx_auth(body:, context:)
            raise('Missing authorization header') unless context.env['HTTP_AUTHORIZATION']

            remote_node_id = context.settings.manager.api_auth.verify_http_authorization_header_value(
              header_value: context.env['HTTP_AUTHORIZATION'],
              payload: body,
            )
            
            return remote_node_id
          rescue StandardError => exc
            context.status 401
            context.content_type 'text/plain'
            context.body "Unauthorized"

            return nil
          end
          
          def self._ensure_json_content(context:)
            return true if context.env['CONTENT_TYPE'] == 'application/json'

            context.status 400
            context.content_type 'text/plain'
            context.body "Invalid content type #{context.env['CONTENT_TYPE']}"

            return false
          end
        end
      end
    end
  end
end
