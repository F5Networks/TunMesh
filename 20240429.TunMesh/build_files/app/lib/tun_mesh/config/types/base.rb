module TunMesh
  class Config
    module Types
      class Base
        attr_reader :allow_nil, :default, :description_short, :description_long, :key

        def initialize(description_short:, key:, allow_nil: false, default: nil, description_long: nil, **)
          @allow_nil = allow_nil
          @default = default
          @description_short = description_short
          @description_long = description_long
          @key = key

          {
            key: @key,
            description_short: @description_short,
          }.each_pair do |name, value|
            raise(ArgumentError, "#{key} is required") if value.nil?
          end

          @value = nil
        end

        def default_description
          return nil if required

          "Default value: #{default}"
        end

        def description_block_lines
          lines = []
          lines.push("#{_description_block_required_mark} #{key} (#{description_type}): #{description_short}")
          lines += description_long.split("\n") if description_long
          lines.push(default_description) if default_description

          return lines
        end

        def description_type
          self.class.to_s.split('::')[-1].downcase
        end

        def example_config_lines
          lines = description_block_lines.map { |l| "# #{l}" }
          lines += example_value_lines

          return lines
        end

        def example_value_lines
          return ["#{key}: [Deployment Unique Value]"] if required

          return ["# #{key}: #{default}"]
        end

        def load_config_value(_)
          # This must be redefined in child classes
          # The child class is expected to:
          # - Do any type conversions / validations
          # - Set @value
          raise("INTERNAL ERROR: #{self.class} did not redefine load_config_value")
        end

        def required
          default.nil?
        end

        def to_s
          @value.to_s
        end

        def value
          return @value if @value

          return default
        end

        private

        def _description_block_required_mark
          if required
            '[REQUIRED]'
          else
            '[Optional]'
          end
        end
      end
    end
  end
end
