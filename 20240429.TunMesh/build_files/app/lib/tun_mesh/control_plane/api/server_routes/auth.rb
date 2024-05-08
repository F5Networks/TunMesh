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

          post '/tunmesh/auth/v0/init_session' do
            return unless Helpers.ensure_json_content(context: self)

            req_body = request.body.read
            Helpers.ensure_mutual_auth(
              auth: settings.api_auth.cluster_token,
              body: req_body,
              context: self
            ) do |remote_node_id|
              settings.api_auth.process_init_session_request(raw_request: req_body, remote_node_id: remote_node_id)
            end
          end

          post '/tunmesh/auth/v0/init_session/:remote_node_id' do |remote_node_id|
            return unless Helpers.ensure_json_content(context: self)

            session_auth = settings.api_auth.session_auth_for_node_id(id: remote_node_id)
            if session_auth
              req_body = request.body.read
              Helpers.ensure_mutual_auth(
                auth: session_auth,
                body: req_body,
                context: self
              ) do
                settings.api_auth.process_init_session_request(raw_request: req_body, remote_node_id: remote_node_id)
              end
            else
              status 404
            end
          end
        end
      end
    end
  end
end
