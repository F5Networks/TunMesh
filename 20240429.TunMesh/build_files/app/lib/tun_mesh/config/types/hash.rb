require_relative 'multi_base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class Hash < MultiBase
        def initialize(**kwargs)
          @value = {}

          super
        end

        def example_value_lines
          lines = [
            "#{key}:",
            "  [Deployment Unique Key 1]: [Deployment Unique Value 1]",
            "  [Deployment Unique Key 2]: [Deployment Unique Value 2]",
            "  ...",
            "  [Deployment Unique Key n]: [Deployment Unique Value n]",
          ]

          return lines if required
          return lines.map { |l| "# #{l}"}
        end

        def load_config_value(value:, **kwargs)
          if value.nil? && @allow_nil
            @value = []
            return
          end

          raise(Errors::TypeError, "Not a hash") unless value.is_a? ::Hash

          @value = value.transform_values do |item|
            @value_type.new(**@init_kwargs).tap { |item_obj| item_obj.load_config_value(value: item, **kwargs) }
          end
        end
      end
    end
  end
end
