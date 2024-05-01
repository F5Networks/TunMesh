require_relative 'base'

module TunMesh
  class Config
    module Types
      class Bool < Base
        def load_config_value(value:, **)
          @value = _parse_value(value)
        end

        private

        def _parse_value(value)
          case value
          when ::TrueClass
            return true
          when ::FalseClass
            return false
          when ::String
            return true if value.downcase == 'true'
            return false if value.downcase == 'false'

            raise(Errors::ValueError, 'Not a boolean string value')
          else
            raise(Errors::TypeError, "Unknown type #{value.class}")
          end
        end
      end
    end
  end
end
