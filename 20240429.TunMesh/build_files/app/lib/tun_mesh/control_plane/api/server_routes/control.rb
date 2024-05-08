require 'sinatra/extension'
require 'sinatra/json'
require './lib/tun_mesh/config'
require_relative 'helpers'

module TunMesh
  module ControlPlane
    class API
      module ServerRoutes
        module Control
          extend Sinatra::Extension

          # Args are passed in via Sinatra .set in TunMesh::ControlPlane::API::Server.run!
          # This const defines the args this route needs.
          REQUIRED_ARGS = %i[api_auth manager].freeze

          get '/tunmesh/control/v0/node_info' do
            # No inbound auth, as this endpoint is intended for use when the other end doesn't know
            #   our ID (Bootstrapping by URL only) and as such can't set the aud claim.
            # Our ID isn't secret, so rather than add a exception to the Auth class just add this endpoint.
            # The advertise URL is also not secret, and is included in case the request came in a load balancer.
            #
            # No return auth, as that could be used to crack the cluster shared secret, which is the weakest and not auto-rotated.
            json({
                   id: TunMesh::CONFIG.node_id,
                   listen_url: TunMesh::CONFIG.values.clustering.control_api_advertise_url.to_s
                 })
          end

          # Deprecated, /tunmesh/control/v0/node_info is now used.
          # Kept for 0.4 -> 0.5 compatibility (One way, 0.5 registering to 0.4 will fail.)
          # Same auth semantics as /tunmesh/control/v0/node_info
          get '/tunmesh/control/v0/node_info/id' do
            json({ id: TunMesh::CONFIG.node_id })
          end

          post '/tunmesh/control/v0/packet/rx/:remote_node_id' do |remote_node_id|
            return unless Helpers.ensure_json_content(context: self)

            session_auth = settings.api_auth.session_auth_for_node_id(id: remote_node_id)
            if session_auth
              body = request.body.read
              return unless Helpers.ensure_rx_auth(
                auth: session_auth,
                body: body,
                context: self
              )

              settings.manager.receive_packet(packet_json: body, source: remote_node_id)
              status 204
            else
              status 404
            end
          end

          get '/tunmesh/control/v0/registrations' do
            json settings.manager.registrations
          end

          # Bootstrap path: Takes the cluster token
          post '/tunmesh/control/v0/registrations/register' do
            return unless Helpers.ensure_json_content(context: self)

            begin
              body = request.body.read
              Helpers.ensure_mutual_auth(
                auth: settings.api_auth.cluster_token,
                body: body,
                context: self
              ) do |remote_node_id|
                settings.manager.registrations.process_registration(raw_payload: body, remote_node_id: remote_node_id)

                # Respond with our own info, to allow for a two way sync
                settings.manager.registrations.outbound_registration_payload
              end
            rescue TunMesh::ControlPlane::Registrations::RegistrationFromSelf
              status 421
              body 'Registration to self'
            rescue TunMesh::ControlPlane::Registrations::RegistrationFailed
              status 400
              body 'Failed'
            end
          end

          # Re-register path, session auth
          # Separate path because, well because it's easiest this way.
          post '/tunmesh/control/v0/registrations/register/:remote_node_id' do |remote_node_id|
            return unless Helpers.ensure_json_content(context: self)

            session_auth = settings.api_auth.session_auth_for_node_id(id: remote_node_id)
            if session_auth
              begin
                body = request.body.read
                Helpers.ensure_mutual_auth(
                  auth: session_auth,
                  body: body,
                  context: self
                ) do
                  settings.manager.registrations.process_registration(raw_payload: body, remote_node_id: remote_node_id)

                  # Respond with our own info, to allow for a two way sync
                  settings.manager.registrations.outbound_registration_payload
                end
              rescue TunMesh::ControlPlane::Registrations::RegistrationFromSelf
                status 421
                body 'Registration to self'
              rescue TunMesh::ControlPlane::Registrations::RegistrationFailed
                status 400
                body 'Failed'
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
