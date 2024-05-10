require 'base64'
require 'openssl'

require './lib/tun_mesh/config'
require_relative '../asymmetric_encryption'

module TunMesh
  module ControlPlane
    class API
      class Auth
        module AsymmetricEncryption
          class Local
            def initialize
              @rsa_private = AsymmetricEncryption::ALGORITHM.generate(TunMesh::CONFIG.values.clustering.auth.pub_key_size)
            end

            def decrypt(ciphertext:)
              return @rsa_private.decrypt(Base64.decode64(ciphertext))
            end

            def public_key
              Base64.strict_encode64(@rsa_private.public_key.to_der)
            end
          end
        end
      end
    end
  end
end
