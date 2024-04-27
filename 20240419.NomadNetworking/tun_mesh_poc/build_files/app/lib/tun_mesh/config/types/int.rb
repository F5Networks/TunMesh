require_relative 'base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class Int < Base
        def initialize(**kwargs)
          super

          @min = kwargs.fetch(:min, -(2**63))
          @max = kwargs.fetch(:max, 2**63)
        end

        def load_config_value(value:, **)
          @value = Integer(value)
          raise(Errors::TypeError, "Value outside allowed range #{min} .. #{max}") if @value < @min || @value > @max
        end

        def to_f
          @value
        end

        def to_i
          @value
        end
      end
    end
  end
end
