require 'uri'
require_relative 'base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class URL < Base
        def load_config_value(value:, **)
          @value = URI.parse(value)
        end
      end
    end
  end
end
