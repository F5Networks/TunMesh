require_relative 'base'

module TunMesh
  class Config
    module Types
      class String < Base
        def initialize(**kwargs)
          @min_length = kwargs[:min_length]
          @max_length = kwargs[:max_length]

          super
        end

        def load_config_value(value:, **)
          @value = value.to_s

          raise(Errors::ValueError, "Value length #{@value.length} below minimum #{@min_length}") if @min_length && @value.length < @min_length
          raise(Errors::ValueError, "Value length #{@value.length} below maximum #{@max_length}") if @max_length && @value.length > @max_length
        end
      end
    end
  end
end
