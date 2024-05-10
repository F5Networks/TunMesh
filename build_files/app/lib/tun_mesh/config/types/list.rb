require_relative 'multi_base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class List < MultiBase
        def initialize(**kwargs)
          @value = []

          super
        end

        def example_value_lines
          lines = [
            "#{key}:",
            '  - [Deployment Unique Value 1]',
            '  - [Deployment Unique Value 2]',
            '  ...',
            '  - [Deployment Unique Value n]'
          ]

          return lines if required

          return lines.map { |l| "# #{l}" }
        end

        def load_config_value(value:, **kwargs)
          if value.nil? && @allow_nil
            @value = []
            return
          end

          raise(Errors::TypeError, 'Not a list') unless value.is_a? Array

          @value = value.map do |item|
            @value_type.new(**@init_kwargs).tap { |item_obj| item_obj.load_config_value(value: item, **kwargs) }
          end
        end
      end
    end
  end
end
