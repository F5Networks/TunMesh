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

          post '/tunmesh/control/v0/packet/rx' do
            return unless Control._ensure_json_content(self)
            return unless Control._ensure_auth(self)

            registration = settings.manager.receive_packet(packet_json: request.body.read)
            status 204
          end

          get '/tunmesh/control/v0/registrations' do
            json settings.manager.registrations
          end

          post '/tunmesh/control/v0/registrations/register' do
            return unless Control._ensure_json_content(self)
            return unless Control._ensure_auth(self)
            
            begin
              registration = settings.manager.registrations.process_registration(request.body.read)

              # Respond with our own info, to allow for a two way sync
              response.headers['Authorization'] = settings.manager.api_auth.new_http_authorization_header_value
              json settings.manager.registrations.outbound_registration_payload
            rescue TunMesh::ControlPlane::Registrations::RegistrationFromSelf
              status 421
              body "Registration to self"
            end
          end
          
          private

          def self._ensure_auth(context)
            raise('Missing authorization header') unless context.env['HTTP_AUTHORIZATION']

            context.settings.manager.api_auth.verify_http_authorization_header_value(context.env['HTTP_AUTHORIZATION'])
            return true
          rescue StandardError => exc
            # TODO: Logger
            STDERR.puts("#{context.request.path} request failed: #{exc.class}: #{exc}")
            
            context.status 401
            context.content_type 'text/plain'
            context.body "Unauthorized"

            return false
          end
          
          def self._ensure_json_content(context)
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
