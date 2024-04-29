require_relative 'base'

module TunMesh
  class Config
    module Types
      class Enum < Base
        def initialize(**kwargs)
          @allowed_values_description = kwargs.fetch(:allowed_values)
          @allowed_values_flat = @allowed_values_description.keys.map(&:to_s)

          super
        end

        def description_block_lines
          lines = []
          lines.push("#{_description_block_required_mark} #{key} (#{self.class}): #{description_short}")
          lines += description_long.split("\n") if description_long
          lines.push("One of:")
          @allowed_values_description.each_pair do |value, description|
            lines.push(" - #{value}:#{ value == default ? ' (Default)' : ''} #{description}")
          end

          return lines
        end

        def load_config_value(value:, **)
          @value = value.to_s
          
          raise(Errors::ValueError, "Must be one of #{@allowed_values_flat}") unless @allowed_values_flat.include?(@value)
        end
      end
    end
  end
end
