require 'jwt'
require 'logger'

module TunMesh
  module ControlPlane
    class Auth
      class AuthError < StandardError
      end

      JWT_ALGORITHM = 'HS256'.freeze
      
      def initialize(manager:, secret:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager
        @secret = secret
      end

      def new_http_authorization_header_value
        "Bearer: #{new_token}"
      end
      
      def new_token
        iat = Time.now.to_i
        return JWT.encode(
                 {
                   iss: @manager.id,
                   iat: iat,
                   nbf: (iat - 5), # TODO: Hardcoded time
                   exp: (iat + 45) # TODO: Hardcoded time
                 },
                 @secret,
                 JWT_ALGORITHM
               )
      end

      def verify(token:)
        decoded_token = JWT.decode(token, @secret, true, { algorithm: JWT_ALGORITHM })
        @logger.debug("Validated token issued by #{decoded_token[0]['iss']}")
        return decoded_token[0]
      rescue StandardError => exc
        @logger.warn("Authentication failed: #{exc.class}: #{exc}")
        raise(AuthError, 'Failed.')
      end

      def verify_http_authorization_header_value(value)
        raise(AuthError, 'No header contents') unless value

        split_auth_header = value.split
        raise(AuthError, 'Invalid authorization header') if split_auth_header.length != 2 || split_auth_header[0].downcase != 'bearer:'
        verify(token: split_auth_header[1])
      end
    end
  end
end

      
        
                                   
