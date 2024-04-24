require 'httparty'
require 'logger'
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
          @remote_url = remote_url
        end

        def register(payload:)
          raise(ArgumentError, "Payload must be a TunMesh::ControlPlane::Structs::Registration, got #{payload.class}") unless payload.is_a? TunMesh::ControlPlane::Structs::Registration
          return _post(path: 'tunmesh/control/v0/registrations/register',
                       payload: payload)
        end

        def transmit_packet(packet:)
          raise(ArgumentError, "Payload must be a TunMesh::IPC::Packet, got #{payload.class}") unless payload.is_a? TunMesh::IPC::Packet
          return _post(path: 'tunmesh/control/v0/packet/rx',
                       payload: packet)
        end

        private

        def _post(path:, payload:)
          # TODO: URL builder lib
          url = "#{@remote_url}/#{path}"
          @logger.debug { "Performing HTTP POST to #{url}" }
        
          # TODO: Connection reuse
          resp = HTTParty.post(url,
                               body: payload.to_json,
                               headers: {
                                 'Authorization' => "Bearer: #{@manager.api_auth.new_token}",
                                 'Content-Type' => 'application/json'
                               },
                               # As this is using advertised, dynamic URLs the CN won't match.
                               # HTTParty doesn't give us enough granularity over the SSL API to verify the CA but not the CN
                               # Impersonation attacks are intended to be caught by the request JWT auth
                               verify: false 
                            )
          return nil if resp.code == 204
          raise(RequestException.new("HTTP POST to #{url} returned #{resp.code}", resp.code)) if resp.code < 200 || resp.code >= 300

          raise(RequestException.new("HTTP POST to #{url} returned unexpected content/code #{resp.headers['content-type']} / #{resp.code}", resp.code)) unless resp.code == 200
          raise(RequestException.new("HTTP POST to #{url} returned content type #{resp.headers['content-type']}", resp.code)) if resp.headers['content-type'] != 'application/json'

          begin
            token_claims = @manager.api_auth.verify_http_authorization_header_value(resp.headers['authorization'])
            # TODO: Improve this
            raise("Response authentication issuer mismatch.") if token_claims['iss'] == @manager.id
          rescue StandardError => exc
            raise(RequestException.new("HTTP POST to #{url} failed response authorization verification: #{exc.class}: #{exc}", resp.code))
          end
          
          
          return resp.body
        end
      end
    end
  end
end
