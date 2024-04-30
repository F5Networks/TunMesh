require 'base64'
require 'json'
require 'logger'
require 'openssl'

require './lib/tun_mesh/config'
require_relative 'auth/token'

module TunMesh
  module ControlPlane
    class API
      class Auth
        def initialize(api:)
          @logger = Logger.new(STDERR, progname: self.class.to_s)
          @api = api

          @rsa_private = OpenSSL::PKey::RSA.generate 2048
        end

        def cluster_token
          @cluster_token ||= Token.new(id: 'Cluster Auth', secret: TunMesh::CONFIG.values.clustering.auth.secret).freeze
        end

        def process_init_session_request(raw_request:, remote_node_id:)
          @logger.debug("Processing session auth update request from #{remote_node_id}")
          remote_api_client = @api.client_for_node_id(id: remote_node_id)
          return 404 unless remote_api_client

          begin
            request = JSON.parse(raw_request)

            auth_id = request.fetch('id')
            new_secret = rsa_decrypt(cyphertext: Base64.decode64(request.fetch('secret')))
          rescue StandardError => exc
            @logger.warn("Invalid session auth update request from #{remote_node_id}: #{exc.class}: #{exc}")
            return 400
          end

          remote_api_client.session_auth = Token.new(id: auth_id, secret: new_secret)

          @logger.info("Successfully updated session auth for #{remote_node_id} to #{auth_id}")
          return 204
        end

        def remote_node_session_auth(remote_node_id:)
          remote_client = @api.client_for_node_id(id: remote_node_id)
          return nil unless remote_client
          return remote_client.session_auth
        end

        def rsa_decrypt(cyphertext:)
          return @rsa_private.decrypt(cyphertext)
        end

        def rsa_public
          @rsa_private.public_key
        end
      end
    end
  end
end
