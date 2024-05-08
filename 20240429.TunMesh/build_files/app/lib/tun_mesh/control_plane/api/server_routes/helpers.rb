module TunMesh
  module ControlPlane
    class API
      module ServerRoutes
        module Helpers
          def self.ensure_mutual_auth(auth:, body:, context:)
            remote_node_id = ensure_rx_auth(auth: auth, body: body, context: context)
            return if remote_node_id.nil?

            raw_payload, code = yield(remote_node_id)
            code ||= 200

            context.status(code)
            if code == 200
              # Not using the JSON extension here as the body and auth payload must match
              payload = raw_payload.to_json

              context.response.headers['Authorization'] = auth.new_http_authorization_header_value(payload: payload, remote_node_id: remote_node_id)
              context.content_type('application/json')
              context.body(payload)
            else
              context.body(raw_payload)
            end
          end

          def self.ensure_rx_auth(auth:, body:, context:)
            raise('Missing authorization header') unless context.env['HTTP_AUTHORIZATION']

            remote_node_id = auth.verify_http_authorization_header_value(
              header_value: context.env['HTTP_AUTHORIZATION'],
              payload: body
            )

            return remote_node_id
          rescue StandardError => exc
            context.status 401
            context.content_type 'text/plain'
            context.body 'Unauthorized'

            return nil
          end

          def self.ensure_json_content(context:)
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
