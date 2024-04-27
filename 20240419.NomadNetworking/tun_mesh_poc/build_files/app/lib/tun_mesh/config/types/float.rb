require_relative 'base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class Float < Base
        def load_config_value(value:, **)
          @value = Float(value)
        end

        def to_f
          @value
        end

        def to_i
          @value.to_i
        end
      end
    end
  end
end
