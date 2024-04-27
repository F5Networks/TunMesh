require_relative 'base'

module TunMesh
  class Config
    module Types
      class Timing < Base
        def initialize(**kwargs)
          super

          @min = kwargs.fetch(:min, 0.5)
          @max = kwargs.fetch(:max, 3600)
          @value = 1.0
        end

        def load_config_value(value:, **)
          case value
          when Float
            @value = value
          when Integer
            @value = value
          when String
            @value = _parse_string_value(value)
          else
            raise(Errors::TypeError, "Cannot parse type #{value.class} into timing value")
          end

          raise(Errors::TypeError, "Value outside allowed range #{min} .. #{max}") if @value < @min || @value > @max
        end

        private

        def _parse_string_value(value)
          case value[-1].downcase
          when 's'
            return Float(value[0..-2])
          when 'm'
            return Float(value[0..-2]) * 60
          when 'h'
            return Float(value[0..-2]) * 3600
          when 'd'
            return Float(value[0..-2]) * 86400
          else
            return Float(value)
          end
        end
      end
    end
  end
end
