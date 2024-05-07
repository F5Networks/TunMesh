require 'base64'
require 'json'
require 'logger'

require './lib/tun_mesh/config'
require_relative 'auth/token'
require_relative 'auth/asymmetric_encryption/local'
require_relative 'auth/asymmetric_encryption/remote'

module TunMesh
  module ControlPlane
    class API
      class Auth
        attr_reader :asymmetric_encryption

        def initialize(api:)
          @logger = Logger.new($stderr, level: TunMesh::CONFIG.values.logging.level, progname: self.class.to_s)
          @api = api

          @asymmetric_encryption = AsymmetricEncryption::Local.new
        end

        def cluster_token
          @cluster_token ||= Token.new(id: 'Cluster Auth', secret: TunMesh::CONFIG.values.clustering.auth.secret).freeze
        end

        def process_init_session_request(raw_request:, remote_node_id:)
          @logger.debug("Processing session auth update request from #{remote_node_id}")
          session_auth = session_auth_for_node_id(id: remote_node_id)
          return 'Failed', 404 unless session_auth

          new_secret = Auth::Token.random_secret

          begin
            request = JSON.parse(raw_request)
            remote_public_key = request.fetch('public_key')
          rescue StandardError => exc
            @logger.warn("Invalid session auth update request from #{remote_node_id}: #{exc.class}: #{exc}")
            return 'Failed', 400
          end

          begin
            remote_asymmetric_encryption = AsymmetricEncryption::Remote.new(public_key: remote_public_key)
            response_secret = remote_asymmetric_encryption.encrypt(payload: new_secret)
          rescue StandardError => exc
            @logger.warn("Failed to encrypt secret with provided public key from #{remote_node_id}: #{exc.class}: #{exc}")
            @logger.debug(exc.backtrace)
            return 'Failed', 400
          end

          session_auth.inbound_auth = Auth::Token.new(
            id: SecureRandom.uuid,
            secret: new_secret
          )

          @logger.info("Successfully updated inbound session auth for #{remote_node_id} to #{session_auth.inbound_auth.id}")
          return {
            id: session_auth.inbound_auth.id,
            secret: response_secret
          }
        rescue StandardError => exc
          @logger.error("Failed to process session auth update request from #{remote_node_id}: #{exc.class}: #{exc}")
          @logger.debug(exc.backtrace)
          return 'Failed', 503
        end

        def session_auth_for_node_id(id:)
          @api.manager.registrations.node_by_id(id)&.session_auth
        end
      end
    end
  end
end
