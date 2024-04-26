require 'sinatra/extension'
require 'sinatra/json'
require_relative 'helpers'

module TunMesh
  module ControlPlane
    class API
      module ServerRoutes
        module Auth
          extend Sinatra::Extension
          
          # Args are passed in via Sinatra .set in TunMesh::ControlPlane::API::Server.run!
          # This const defines the args this route needs.
          REQUIRED_ARGS = %i[api_auth].freeze

          get '/tunmesh/auth/v0/rsa_public' do
            status 200
            content_type 'text/plain'
            body settings.api_auth.rsa_public.to_s
          end

          post '/tunmesh/auth/v0/init_session' do
            return unless Helpers.ensure_json_content(context: self)
            
            body = request.body.read
            remote_node_id = Helpers.ensure_rx_auth(auth: settings.api_auth.cluster_token, body: body, context: self)
            
            resp_status = settings.api_auth.process_init_session_request(raw_request: body, remote_node_id: remote_node_id)
            status resp_status
            body('Failed') unless resp_status == 204
          end
        end
      end
    end
  end
end
