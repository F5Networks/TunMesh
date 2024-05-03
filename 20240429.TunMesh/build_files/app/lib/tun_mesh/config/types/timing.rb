require_relative 'base'

module TunMesh
  class Config
    module Types
      class Timing < Base
        def initialize(**kwargs)
          super

          @min = kwargs.fetch(:min, 0.5)
          @max = kwargs.fetch(:max, 3600)
        end

        def load_config_value(value:, **)
          case value
          when ::Float
            @value = value
          when ::Integer
            @value = value
          when ::String
            @value = _parse_string_value(value)
          else
            raise(Errors::TypeError, "Cannot parse type #{value.class} into timing value")
          end

          raise(Errors::ValueError, "Value outside allowed range #{@min} .. #{@max}") if @value < @min || @value > @max
        end

        private

        def _parse_string_value(value)
          case value[-1].downcase
          when 's'
            return _parse_string_value_no_suffix(value[0..-2])
          when 'm'
            return _parse_string_value_no_suffix(value[0..-2]) * 60
          when 'h'
            return _parse_string_value_no_suffix(value[0..-2]) * 3600
          when 'd'
            return _parse_string_value_no_suffix(value[0..-2]) * 86400
          else
            return _parse_string_value_no_suffix(value)
          end
        end

        def _parse_string_value_no_suffix(value)
          split_value = value.split('..')
          if split_value.length == 1
            return Float(value)
          elsif split_value.length == 2
            range_low = Float(split_value[0])
            range_high = Float(split_value[1])
            return(rand(range_low..range_high))
          else
            raise(Errors::ValueError, 'Unparsable value')
          end
        end
      end
    end
  end
end
