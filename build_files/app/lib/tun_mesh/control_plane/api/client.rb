require 'base64'
require 'openssl'
require 'pathname'
require 'persistent_http'
require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'
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

        attr_reader :remote_id, :remote_url

        def initialize(api_auth:, remote_url:)
          raise(ArgumentError, 'Missing api_auth') if api_auth.nil?
          raise(ArgumentError, 'Missing remote_url') if remote_url.nil?

          # Early logger for remote_info GET
          @logger = TunMesh::Logger.new(id: "#{self.class}(#{remote_url})")

          @api_auth = api_auth
          @remote_url = remote_url.to_s

          remote_info_resp = remote_info
          @remote_id = remote_info_resp['id']
          @logger = TunMesh::Logger.new(id: "#{self.class}(#{@remote_id}@#{remote_url})")

          if remote_info_resp['listen_url'] != @remote_url
            # This is a handler for bootstrapping via load balanced URLs
            # If we're passed a load balancer, immediately drop to the advertised URL
            # Otherwise the session calls will get out of sync, this API protocol needs a 1:1 URL -> node mapping
            # This is normal on startup, but not post bootstrap and only if configured with non-sticky load balancers in the bootstrap URL list.
            @logger.warn("Updating remote_url from #{@remote_url} to #{remote_info_resp['listen_url']}")
            @remote_url = remote_info_resp['listen_url']
            @logger = TunMesh::Logger.new(id: "#{self.class}(#{@remote_id}@#{@remote_url})")
          end

          _init_persistent_http
          @logger.debug { 'Initialized' }
        end

        # Inits the session auth with the other end
        # Intended to be called by API::Auth::Session
        def init_session_token(session_auth_token:)
          payload = {
            public_key: @api_auth.asymmetric_encryption.public_key
          }

          if session_auth_token.nil?
            @logger.info { 'initializing session auth using the cluster token' }
            raw_resp = _post_mutual(
              auth: @api_auth.cluster_token,
              path: '/tunmesh/auth/v0/init_session',
              payload: payload,
              valid_response_codes: [200]
            )
          else
            @logger.info { "initializing session auth using existing session auth #{session_auth_token.id}" }
            raw_resp = _post_mutual(
              auth: session_auth_token,
              path: "/tunmesh/auth/v0/init_session/#{TunMesh::CONFIG.node_id}",
              payload: payload,
              valid_response_codes: [200]
            )
          end

          decoded_resp = JSON.parse(raw_resp)
          return Auth::Token.new(
            id: decoded_resp.fetch('id'),
            secret: @api_auth.asymmetric_encryption.decrypt(ciphertext: decoded_resp.fetch('secret'))
          )
        end

        def register(payload:)
          raise(ArgumentError, "Payload must be a TunMesh::ControlPlane::Structs::Registration, got #{payload.class}") unless payload.is_a? TunMesh::ControlPlane::Structs::Registration

          # Key off session auth alone, as if auth_session exists then there is a saved registration
          return _register_bootstrap(payload: payload) unless auth_session

          begin
            return _register_session(payload: payload)
          rescue RequestException => exc
            case exc.code.to_s
            when '404'
              @logger.warn('Re-registration returned 404: This node not known to the remote node')
            else
              raise exc
            end
          end

          return _register_bootstrap(payload: payload)
        end

        def remote_info
          url = Pathname.new(@remote_url).join('tunmesh/control/v0/node_info')

          _init_persistent_http(non_persistent: true) unless @persistent_http
          decoded_resp = JSON.parse(_get_unauthed(path: url.to_s))
          raise(RequestException.new('Invalid response: Missing id', resp.code)) unless decoded_resp['id']
          raise(RequestException.new('Invalid response: Missing listen_url', resp.code)) unless decoded_resp['listen_url']

          return decoded_resp
        end

        def auth_session
          @auth_session ||= @api_auth.auth_session_for_node_id(id: remote_id)
        end

        def transmit_packet(packet:)
          raise(ArgumentError, "Packet must be a TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

          auth_session.auth_wrapper do |auth|
            return _post_mutual(
              auth: auth,
              path: "/tunmesh/control/v0/packet/rx/#{TunMesh::CONFIG.node_id}",
              payload: packet,
              valid_response_codes: [204]
            )
          end
        end

        def transmit_packet_batch(packets:)
          # packets being a array of TunMesh::IPC::Packet is expected to be enforced by the caller
          auth_session.auth_wrapper do |auth|
            return _post_mutual(
              auth: auth,
              path: "/tunmesh/control/v0/packet/rx/#{TunMesh::CONFIG.node_id}/batch",
              payload: packets.map(&:to_json), # Pre-jsonify the payloads as it makes the RX path much easier
              valid_response_codes: [204]
            )
          end
        end

        private

        def _get_unauthed(path:, expected_content_type: 'application/json')
          request = Net::HTTP::Get.new(path)
          @logger.debug { "Performing HTTP GET (No auth) to #{path}" }
          resp = @persistent_http.request(request)
          @logger.debug { "HTTP GET to #{path} returned #{resp.code}" }

          raise(RequestException.new("HTTP GET to #{path} returned unexpected content/code #{resp.content_type} / #{resp.code}", resp.code)) unless resp.code == '200'
          raise(RequestException.new("HTTP GET to #{path} returned content type #{resp.content_type}", resp.code)) unless resp.content_type == expected_content_type

          resp.body
        end

        def _init_persistent_http(**kwargs)
          ca_file_path = TunMesh::CONFIG.values.control_api.ssl.ca_file_path
          ca_file_path = TunMesh::CONFIG.values.control_api.ssl.cert_file_path unless ca_file_path&.file?

          common_args = {
            name: "#{self.class}(#{@remote_url})",
            url: @remote_url,

            force_retry: true,
            pool_size: 3, # Only expected to be accessed by the Registrations::RemoteNode worker and the Registrations worker
            pool_timeout: 5,

            verify_mode: OpenSSL::SSL::VERIFY_PEER,
            # verify_hostname requires https://github.com/bpardee/persistent_http/pull/10
            verify_hostname: TunMesh::CONFIG.values.control_api.ssl.verify_hostname,
            ca_file: ca_file_path.to_s,

            open_timeout: TunMesh::CONFIG.values.process.timing.request_timeout,
            read_timeout: TunMesh::CONFIG.values.process.timing.request_timeout,
            warn_timeout: TunMesh::CONFIG.values.process.timing.request_timeout
          }

          common_args[:logger] = @logger if @logger
          full_args = common_args.merge(kwargs)
          @logger.debug { "Initializing PersistentHTTP with args #{full_args}" }

          @persistent_http = PersistentHTTP.new(**full_args)
        end

        def _post_mutual(auth:, path:, payload:, valid_response_codes:)
          request = Net::HTTP::Post.new(path)
          raw_payload = payload.to_json
          request.body = raw_payload
          request.content_type = 'application/json'

          # NOTE: No SSL Verification
          # As this is expected to be using using advertised, dynamic URLs based on IP:Port combos the CN won't match.
          # Impersonation attacks are intended to be caught by the request JWT auth
          request['Authorization'] = auth.new_http_authorization_header_value(payload: raw_payload, remote_node_id: remote_id)

          @logger.debug { "Performing HTTP POST to #{path}" }
          resp = @persistent_http.request(request)
          @logger.debug { "HTTP POST to #{path} returned #{resp.code}" }

          return nil if resp.code == '204' && valid_response_codes.include?(resp.code.to_i)

          raise(RequestException.new("HTTP POST to #{path} returned #{resp.code}", resp.code)) if resp.code.to_i < 200 || resp.code.to_i >= 300
          raise(RequestException.new("HTTP POST to #{path} returned unexpected content/code #{resp.content_type} / #{resp.code}", resp.code)) unless valid_response_codes.include?(resp.code.to_i)
          raise(RequestException.new("HTTP POST to #{path} returned content type #{resp.content_type}", resp.code)) if resp.content_type != 'application/json'

          body = resp.body

          begin
            auth.verify_http_authorization_header_value(header_value: resp['authorization'], payload: body)
          rescue StandardError => exc
            raise(RequestException.new("HTTP POST to #{path} using auth #{auth.id} failed response authorization verification: #{exc.class}: #{exc}", resp.code))
          end

          return body
        end

        # Register to the other node, in bootstrap mode using the cluster token
        # This should only happen on boot, if it's a regular fallback something is wrong.
        def _register_bootstrap(payload:)
          @logger.info { "Registering to #{remote_id} in bootstrap mode using the cluster token." }

          # This doesn't use session auth as, until we're registered on the other side, there is no client object on the remote side to take the token
          return _post_mutual(
            auth: @api_auth.cluster_token,
            path: '/tunmesh/control/v0/registrations/register',
            payload: payload,
            valid_response_codes: [200]
          )
        end

        # Re-register to the other node using the session token
        # This is the normal re-registration process, which also serves as a check and self-heal trigger on the session token.
        def _register_session(payload:)
          @logger.debug { "Registering to #{remote_id} using the session token" }

          auth_session.auth_wrapper do |auth|
            return _post_mutual(
              auth: auth,
              path: "/tunmesh/control/v0/registrations/register/#{TunMesh::CONFIG.node_id}",
              payload: payload,
              valid_response_codes: [200]
            )
          end
        end
      end
    end
  end
end
