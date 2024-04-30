require_relative 'types/base'
require_relative 'errors'

module TunMesh
  class Config
    class Version < Types::Base
      VERSION = "1.0"

      def initialize
        super(
          key: 'config_version',
          description_short: 'Configuration file schema version',
        )
      end

      def example_value_lines
        return ["#{key}: #{VERSION}"]
      end

      def load_config_value(value:, **)
        @value = value.to_s
        raise(Errors::ValueError, "Unknown config version") if @value != VERSION
      end

      def required
        true
      end
    end
  end
end
