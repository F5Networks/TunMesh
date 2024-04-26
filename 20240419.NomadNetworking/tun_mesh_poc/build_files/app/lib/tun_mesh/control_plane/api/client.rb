require 'base64'
require 'logger'
require 'httparty'
require 'openssl'
require 'pathname'
require 'persistent_http'
require './lib/tun_mesh/config'
require_relative '../structs/registration'
require_relative '../../ipc/packet'

module TunMesh
  module ControlPlane
    class API
      class Client
        class RequestException < RuntimeError
          attr_reader :code
        
          def initialize(message, code)
            @code = code
            super(message)
          end
        end

        attr_reader :remote_url
        
        def initialize(api_auth:, remote_url:, remote_id: nil)
          raise(ArgumentError, "Missing api_auth") if api_auth.nil? 
          raise(ArgumentError, "Missing remote_url") if remote_url.nil?
         
          @api_auth = api_auth
          @remote_id = remote_id
          @remote_url = remote_url
          @logger = Logger.new(STDERR, progname: "#{self.class}(#{self.remote_id}@#{remote_url})")

          @persistent_http = PersistentHTTP.new(
            :name         => "#{self.class}(#{remote_url})",
            :logger       => @logger,
            :pool_size    => 3, # Only expected to be accessed by the Registrations::RemoteNode worker and the Registrations worker
            :pool_timeout => 5,
            :warn_timeout => 0.25,
            :force_retry  => true,
            :url          => remote_url
          )

          @session_auth_lock = Mutex.new
          @logger.debug("Initialized")
        end

        def remote_pubkey
          @remote_rsa_pubkey ||= OpenSSL::PKey::RSA.new(_get_unauthed(path: '/tunmesh/auth/v0/rsa_public', expected_content_type: 'text/plain'))
        end

        def session_auth
          return @session_auth if @session_auth

          @session_auth_lock.synchronize do
            @logger.debug("Initializing new session auth")
            new_secret = Auth::Token.random_secret
            new_token = Auth::Token.new(
              id: SecureRandom.uuid,
              secret: new_secret
            )

            post_payload = {
              id: new_token.id,
              secret: Base64.encode64(remote_pubkey.public_encrypt(new_secret))
            }

            _post_mutual(
              auth: @api_auth.cluster_token,
              path: '/tunmesh/auth/v0/init_session',
              payload: post_payload,
              valid_response_codes: [204]
            )

            @session_auth = new_token
          end

          @logger.debug("New sesson auth initialized successfully")
          return @session_auth
        end

        def session_auth=(new_auth)
          raise(ArgumentError, "new_auth is not a Auth::Token, got #{new_auth.class}") unless new_auth.is_a? Auth::Token
          @session_auth = new_auth
        end

        def register(payload:)
          raise(ArgumentError, "Payload must be a TunMesh::ControlPlane::Structs::Registration, got #{payload.class}") unless payload.is_a? TunMesh::ControlPlane::Structs::Registration

          # This doesn't use session auth as, until we're registered on the other side, there is no client object on the remote side to take the token
          return _post_mutual(
            auth: @api_auth.cluster_token,
            path: '/tunmesh/control/v0/registrations/register',
            payload: payload,
            valid_response_codes: [200]
          )
        end

        def remote_id
          return @remote_id if @remote_id

          url = Pathname.new(@remote_url).join('tunmesh/control/v0/node_info/id')
          begin
            # Don't use @persistent_http or @logger as they're not initialized yet
            # We need the ID to init the logger to init persistent_http
            resp = HTTParty.get(url.to_s, verify: false)

            raise(RequestException.new("HTTP #{resp.code}", resp.code)) if resp.code != 200
            raise(RequestException.new("Invalid response", resp.code)) unless resp['id']
            @remote_id = resp['id']

            return @remote_id
          rescue StandardError => exc
            raise(exc, "Failed to perform ID GET to #{url}: #{exc}")
          end
        end
        
        def transmit_packet(packet:)
          raise(ArgumentError, "Packet must be a TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet
          return _post_mutual(
            auth: session_auth,
            path: "/tunmesh/control/v0/packet/rx/#{TunMesh::CONFIG.node_id}",
            payload: packet,
            valid_response_codes: [204]
          )
        end

        private

        def _get_unauthed(path:, expected_content_type: 'application/json')
          request = Net::HTTP::Get.new(path)
          @logger.debug { "Performing HTTP GET (No auth) to #{path}" }
          resp = @persistent_http.request(request)
          @logger.debug { "HTTP GET to #{path} returned #{resp.code}" }

          raise(RequestException.new("HTTP #{verb} to #{path} returned unexpected content/code #{resp.content_type} / #{resp.code}", resp.code)) unless resp.code == '200'
          raise(RequestException.new("HTTP #{verb} to #{path} returned content type #{resp.content_type}", resp.code)) unless resp.content_type == expected_content_type
          
          body = resp.body
        end

        
#        def _get_mutual(auth:, path:, signature_payload:)
#          request = Net::HTTP::GET.new(path)
#          return _mutual_common(
#            auth: auth,
#            path: path,
#            request: request,
#            signature_payload: signature_payload,
#            valid_response_codes: [200],
#            verb: 'GET'
#          )
#        end

        # TODO: Rename / flatten
        def _post_mutual(auth:, path:, payload:, valid_response_codes:)
          request = Net::HTTP::Post.new(path)
          raw_payload = payload.to_json
          request.body = raw_payload
          request.content_type = 'application/json'

          return _mutual_common(
            auth: auth,
            path: path,
            request: request,
            signature_payload: raw_payload,
            valid_response_codes: valid_response_codes,
            verb: 'POST'
          )
        end

        def _mutual_common(auth:, path:, request:, signature_payload:, valid_response_codes:, verb:)
          # NOTE: No SSL Verification
          # As this is expected to be using using advertised, dynamic URLs based on IP:Port combos the CN won't match.
          # Impersonation attacks are intended to be caught by the request JWT auth
          request['Authorization'] = auth.new_http_authorization_header_value(payload: signature_payload, remote_node_id: remote_id)

          @logger.debug { "Performing HTTP #{verb} to #{path}" }
          resp = @persistent_http.request(request)
          @logger.debug { "HTTP #{verb} to #{path} returned #{resp.code}" }

          return nil if resp.code == '204' && valid_response_codes.include?(resp.code.to_i)

          raise(RequestException.new("HTTP #{verb} to #{path} returned #{resp.code}", resp.code)) if resp.code.to_i < 200 || resp.code.to_i >= 300
          raise(RequestException.new("HTTP #{verb} to #{path} returned unexpected content/code #{resp.content_type} / #{resp.code}", resp.code)) unless valid_response_codes.include?(resp.code.to_i)
          raise(RequestException.new("HTTP #{verb} to #{path} returned content type #{resp.content_type}", resp.code)) if resp.content_type != 'application/json'

          body = resp.body

          begin
            auth.verify_http_authorization_header_value(header_value: resp['authorization'], payload: body)
          rescue StandardError => exc
            raise(RequestException.new("HTTP #{verb} to #{path} failed response authorization verification: #{exc.class}: #{exc}", resp.code))
          end

          return body
        end
      end
    end
  end
end
