require_relative 'errors'

module TunMesh
  class Config
    class Group
      attr_reader :description_short, :description_long, :fields, :key

      def initialize(description_short:, key:, description_long: nil, **)
        @description_short = description_short
        @description_long = description_long
        @key = key

        @fields = []
      end

      def add_field(field)
        raise(RuntimeError, "Output value already read") if @value
        raise(ArgumentError, "Duplicate field #{field.key}") if field_keys.include?(field.key)

        @fields.push(field)
        @fields_by_key = nil
      end

      def description_block_lines
        lines = []
        lines.push("#{key} group#{ required ? '' : ' [Optional]'}: #{description_short}")
        lines += description_long.split("\n") if description_long

        return lines
      end

      def example_config_lines
        lines = description_block_lines.map { |l| "# #{l}" }
        if required
          lines.push("#{key}:")
        else
          lines.push("# #{key}:")
        end

        # Order settings before groups, this makes the config more readable
        setting_fields = fields.reject { |field| field.is_a? Group }.sort_by { |f| f.key }
        group_fields = fields.select { |field| field.is_a? Group }.sort_by { |f| f.key }
        
        setting_fields.each.with_index do |field, index|
          lines.push('') if index > 0
          lines += field.example_config_lines.map { |l| "  #{l}" }
        end

        return lines if group_fields.empty?

        unless setting_fields.empty?
          lines += [
            '',
            '  #',
            "  # #{key} sub groups",
            '  #',
            ''
          ]
        end

        group_fields.each.with_index do |field, index|
          lines.push('') if index > 0
          lines += field.example_config_lines.map { |l| "  #{l}" }
        end
        
        return lines
      end

      def field_keys
        fields_by_key.keys
      end

      def fields_by_key
        @fields_by_key ||= @fields.map { |f| [f.key, f] }.to_h
      end

      def load_config_value(value:, config_obj:)
        raise(Errors::TypeError, 'Not a hash') unless value.is_a?(Hash)

        unknown_keys = (value.keys - field_keys)
        raise(Errors::UnknownKeyError, "Unknown keys #{unknown_keys}, expected keys #{field_keys}") unless unknown_keys.empty?
        
        missing_keys = (fields.select(&:required).map(&:key) - value.keys)
        raise(Errors::MissingKeyError, "Missing keys #{missing_keys}") unless missing_keys.empty?
        
        value.transform_keys { |key| fields_by_key[key] }.each do |field, field_value|
          raise(Errors::ValueError, "Null value") if field_value.nil? && !field.allow_nil
          
          begin
            field.load_config_value(value: field_value, config_obj: config_obj)
          rescue Errors::ParseError => exc
            raise exc
          rescue StandardError => exc
            raise(Errors::ParseError.new("#{exc.class}: #{exc}"))
          end
          
        rescue Errors::ParseError => exc
          exc.prefix_key(key: field.key)
          raise exc if field.is_a?(Group)

          value = (exc.value || field_value)
          raise exc.class.new("Value \"#{value}\": #{exc}", key: exc.key, value: value)
        end
      end

      def required
        @fields.map { |f| f.required }.any?
      end

      def value
        # Return a struct for value for value.key access
        @value ||= Struct.new(*field_keys.map(&:to_sym)).new(**fields_by_key.transform_values(&:value)).freeze
      end
    end
  end
end
