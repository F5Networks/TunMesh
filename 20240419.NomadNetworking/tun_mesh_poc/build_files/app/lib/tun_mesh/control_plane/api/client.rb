require 'logger'
require 'persistent_http'
require_relative '../structs/registration'
require_relative '../../ipc/packet'

module TunMesh
  module ControlPlane
    module API
      class Client
        class RequestException < RuntimeError
          attr_reader :code
        
          def initialize(message, code)
            @code = code
            super(message)
          end
        end
      
        def initialize(manager:, remote_url:)
          raise(ArgumentError, "Missing manager") if manager.nil? 
          raise(ArgumentError, "Missing remote_url") if remote_url.nil?
         
          @manager = manager
          @logger = Logger.new(STDERR, progname: "#{self.class}(#{remote_url})")

          @persistent_http = PersistentHTTP.new(
            :name         => "#{self.class}(#{remote_url})",
            :logger       => @logger,
            :pool_size    => 3, # Only expected to be accessed by the Registrations::RemoteNode worker and the Registrations worker
            :pool_timeout => 5,
            :warn_timeout => 0.25,
            :force_retry  => true,
            :url          => remote_url
          )
        end

        def register(payload:)
          raise(ArgumentError, "Payload must be a TunMesh::ControlPlane::Structs::Registration, got #{payload.class}") unless payload.is_a? TunMesh::ControlPlane::Structs::Registration
          return _post(path: '/tunmesh/control/v0/registrations/register',
                       payload: payload)
        end

        def transmit_packet(packet:)
          raise(ArgumentError, "Packet must be a TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet
          return _post(path: '/tunmesh/control/v0/packet/rx',
                       payload: packet)
        end

        private

        def _post(path:, payload:)
          @logger.debug { "Performing HTTP POST to #{path}" }
          request = Net::HTTP::Post.new(path)
          # NOTE: No SSL Verification
          # As this is expected to be using using advertised, dynamic URLs based on IP:Port combos the CN won't match.
          # Impersonation attacks are intended to be caught by the request JWT auth
          request.body = payload.to_json
          request.content_type = 'application/json'
          request['Authorization'] = @manager.api_auth.new_http_authorization_header_value

          resp = @persistent_http.request(request)
          return nil if resp.code == '204'
          raise(RequestException.new("HTTP POST to #{path} returned #{resp.code}", resp.code)) if resp.code.to_i < 200 || resp.code.to_i >= 300

          raise(RequestException.new("HTTP POST to #{path} returned unexpected content/code #{resp.content_type} / #{resp.code}", resp.code)) unless resp.code == '200'
          raise(RequestException.new("HTTP POST to #{path} returned content type #{resp.content_type}", resp.code)) if resp.content_type != 'application/json'

          begin
            token_claims = @manager.api_auth.verify_http_authorization_header_value(resp['authorization'])
            # TODO: Improve this
            raise("Response authentication issuer mismatch.") if token_claims['iss'] == @manager.id
          rescue StandardError => exc
            raise(RequestException.new("HTTP POST to #{path} failed response authorization verification: #{exc.class}: #{exc}", resp.code))
          end

          return resp.body
        end
      end
    end
  end
end
