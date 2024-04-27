require_relative 'int'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class UInt < Int
        def initialize(**kwargs)
          @base = kwargs.fetch(:base, 10)

          super
        end

        def default_description
          return nil if required
          "Default value: #{_config_default}"
        end

        def example_value_lines
          return ["# #{key}: #{_config_default}"] unless required
          super
        end

        def load_config_value(value:, **)
          super

          raise(Errors::TypeError, "negative value for unsigned integer type") if @value < 0
        end

        private

        def _config_default
          # Yaml only officially supports decimal, octal, and hex
          # https://github.com/yaml/yaml-grammar/blob/master/yaml-spec-1.2.txt
          case @base
          when 16
            "0x#{default.to_s(16)}"
          when 8
            "0o#{default.to_s(8)}"
          else
            default.to_s(10)
          end
        end
      end
    end
  end
end
