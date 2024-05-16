require_relative 'multi_base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      class Hash < MultiBase
        def initialize(**kwargs)
          @value = {}
          @example_value = kwargs.delete(:example_value)

          super
        end

        def example_value_lines
          lines = [
            "#{key}:"
          ]

          if @example_value
            @example_value.each_pair do |ek, ev|
              ev_lines = ev.example_value_lines
              if ev_lines.length == 1
                lines.push("  #{ek}: #{ev_lines[0]}")
              else
                lines.push("  #{ek}:")
                lines += ev_lines.map { |evl| "    #{evl}" }
              end
            end
          else
            lines.push('  [Deployment Unique Key 1]: [Deployment Unique Value 1]')
            lines.push('  [Deployment Unique Key 2]: [Deployment Unique Value 2]')
            lines.push('  ...')
            lines.push('  [Deployment Unique Key n]: [Deployment Unique Value n]')
          end

          return lines if required

          return lines.map { |l| "# #{l}" }
        end

        def load_config_value(value:, **kwargs)
          if value.nil? && @allow_nil
            @value = {}
            return
          end

          raise(Errors::TypeError, 'Not a hash') unless value.is_a? ::Hash

          @value = value.transform_values do |item|
            item_obj = @value_type.new(**@init_kwargs)
            item_obj.load_config_value(value: item, **kwargs)
            item_obj.value
          end
        end
      end
    end
  end
end
