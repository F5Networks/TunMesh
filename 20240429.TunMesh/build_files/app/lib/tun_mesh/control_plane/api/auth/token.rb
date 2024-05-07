require 'digest'
require 'jwt'
require 'logger'
require 'securerandom'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/config'

require_relative 'errors'

module TunMesh
  module ControlPlane
    class API
      class Auth
        class Token
          def self.random_secret
            return SecureRandom.random_bytes(64)
          end

          # Using a basic symmetric algorithm as it's the easiest/fastest
          # Asymmetric keys aren't strictly needed, so favoring the simplicity of symmetric keys
          JWT_ALGORITHM = 'HS256'.freeze

          attr_reader :id, :stamp

          def initialize(id:, secret:)
            @stamp = Time.now.to_f
            @id = id
            @logger = Logger.new(STDERR, level: TunMesh::CONFIG.values.logging.level, progname: "#{self.class}(#{id})")
            @secret = secret
          end

          def age
            Time.now.to_f - stamp
          end

          def new_http_authorization_header_value(**kwargs)
            "Bearer: #{new_token(**kwargs)}"
          end

          def new_token(payload:, remote_node_id:)
            iat = Time.now.to_i
            return JWT.encode(
              {
                iss: TunMesh::CONFIG.node_id,
                iat: iat,
                nbf: (iat - TunMesh::CONFIG.values.process.timing.auth.early_validity_window),
                exp: (iat + TunMesh::CONFIG.values.process.timing.auth.validity_window),
                aud: remote_node_id,
                sig: _payload_sig(payload: payload),
                sub: @id,
              },
              @secret,
              JWT_ALGORITHM
            )
          end

          def verify(payload:, token:)
            decoded_token = JWT.decode(token, @secret, true, { algorithm: JWT_ALGORITHM })
            claims = decoded_token[0].transform_keys(&:to_sym)
            @logger.debug("Decoded token issued by #{claims[:iss]}: Claims: #{claims}")

            raise(AuthError, "Audience Mismatch.  Expected #{TunMesh::CONFIG.node_id}, got #{claims.fetch(:aud)}") if claims.fetch(:aud) != TunMesh::CONFIG.node_id
            raise(AuthError, "Subject Mismatch.  Expected #{@id}, got #{claims.fetch(:sub)}") if claims.fetch(:sub) != @id

            sig = _payload_sig(payload: payload)
            raise(AuthError, "Signature Mismatch.  Expected #{sig}, got #{claims.fetch(:sig)}") if claims.fetch(:sig) != sig

            @logger.debug("Validated token issued by #{claims[:iss]} for payload #{sig} with auth #{id}")

            return claims[:iss]
          rescue StandardError => exc
            @logger.warn("Authentication failed using auth #{id}: #{exc.class}: #{exc}")
            raise(AuthError, 'Failed.')
          end

          def verify_http_authorization_header_value(header_value:, payload:)
            raise(AuthError, 'No header contents') unless header_value

            split_auth_header = header_value.split
            raise(AuthError, 'Invalid authorization header') if split_auth_header.length != 2 || split_auth_header[0].downcase != 'bearer:'

            verify(payload: payload, token: split_auth_header[1])
          end

          private

          def _payload_sig(payload:)
            if payload.is_a? TunMesh::IPC::Packet
              # Use the packet md5 as it's already calculated
              # This is a application specific optimization
              components = [1, payload.md5]
            else
              # Default to SHA256
              components = [0, Digest::SHA256.hexdigest(payload)]
            end

            return components.join('/')
          end
        end
      end
    end
  end
end
