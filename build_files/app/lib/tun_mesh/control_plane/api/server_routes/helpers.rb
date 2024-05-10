require './lib/tun_mesh/logger'

module TunMesh
  module ControlPlane
    class API
      module ServerRoutes
        module Helpers
          def self.logger
            @logger ||= TunMesh::Logger.new(id: self.class.to_s)
          end

          def self.ensure_mutual_auth(auth:, body:, context:)
            remote_node_id = ensure_rx_auth(auth: auth, body: body, context: context)
            return if remote_node_id.nil?

            raw_payload, code = yield(remote_node_id)
            code ||= 200

            logger.debug { "ensure_mutual_auth(#{context.request.path}): Finalizing with code #{code}" }

            context.status(code)
            if code == 200
              # Not using the JSON extension here as the body and auth payload must match
              payload = raw_payload.to_json

              context.response.headers['Authorization'] = auth.new_http_authorization_header_value(payload: payload, remote_node_id: remote_node_id, for_response: true)
              context.content_type('application/json')
              context.body(payload)
            else
              context.body(raw_payload)
            end
          rescue StandardError => exc
            logger.warn("Exception in ensure_mutual_auth(#{context.request.path}): #{exc.class}: #{exc}")
            logger.debug { exc.backtrace }
            raise exc
          end

          def self.ensure_rx_auth(auth:, body:, context:)
            raise('Missing authorization header') unless context.env['HTTP_AUTHORIZATION']

            remote_node_id = auth.verify_http_authorization_header_value(
              header_value: context.env['HTTP_AUTHORIZATION'],
              payload: body
            )

            return remote_node_id
          rescue StandardError => exc
            logger.warn("ensure_rx_auth(#{context.request.path}) failed: #{exc.class}: #{exc}")
            logger.debug { exc.backtrace }

            context.status 401
            context.content_type 'text/plain'
            context.body 'Unauthorized'

            return nil
          end

          def self.ensure_json_content(context:)
            return true if context.env['CONTENT_TYPE'] == 'application/json'

            logger.warn("ensure_json_content(#{context.request.path}) failed: #{context.env['CONTENT_TYPE']}")

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
