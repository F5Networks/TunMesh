require 'base64'
require 'openssl'

require_relative '../asymmetric_encryption'

module TunMesh
  module ControlPlane
    class API
      class Auth
        module AsymmetricEncryption
          class Remote
            def initialize(public_key:)
              @rsa_public = AsymmetricEncryption::ALGORITHM.new(Base64.decode64(public_key))
            end

            def encrypt(payload:)
              Base64.strict_encode64(@rsa_public.public_encrypt(payload))
            end
          end
        end
      end
    end
  end
end
