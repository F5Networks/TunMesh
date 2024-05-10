require_relative '../group'
require_relative '../types/file'

module TunMesh
  class Config
    class ControlAPI < Group
      class SSL < Group
        def initialize
          super(
            key: 'ssl',
            description_short: 'SSL cert settings',
            description_long: <<~EOF
              A SSL cert is required to protect the API and traffic.
              This cert can be reused across multiple nodes and will be used for /health and /monitoring endpoints, which are intended for external consumption.
            EOF
          )

          add_field(
            Types::File.new(
              key: 'ca_file_path',
              default: nil,
              required: false,
              description_short: 'Path to the SSL CA file/bundle inside the container',
              description_long: 'When unset the cert file will be used for SSL verification'
            )
          )

          add_field(
            Types::File.new(
              key: 'cert_file_path',
              description_short: 'Path to the SSL cert file/bundle inside the container'
            )
          )

          add_field(
            Types::File.new(
              key: 'key_file_path',
              description_short: 'Path to the SSL key file inside the container'
            )
          )

          add_field(
            Types::Bool.new(
              key: 'verify_hostname',
              default: false,
              description_short: 'Enable verifying node hostnames in the SSL handshake.',
              description_long: <<~EOF
                Requires node certs to have proper CNs or SANs for the advertise URLs.
                Defaults to false as node advertise_urls are expected to be dynamic.
              EOF
            )
          )
        end
      end
    end
  end
end
