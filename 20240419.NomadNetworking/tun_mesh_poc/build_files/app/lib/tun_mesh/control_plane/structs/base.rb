require 'json'

module TunMesh
  module ControlPlane
    module Structs
      # Base class for all the structs
      class Base
        GETTER_DEFAULT = true
        # Default sets to off, it's expected that most fields will be static for the life of the object
        SETTER_DEFAULT = false

        def self.from_json(raw)
          return new(**JSON.parse(raw).transform_keys(&:to_sym))
        end

        # Child classes are expected to define FIELDS
        def initialize(**args)
          self.class::FIELDS.each_pair do |name, config|
            raise(ArgumentError, "INTERNAL ERROR: Field config for #{name} missing required setting type") unless config[:type]
            raise(ArgumentError, "INTERNAL ERROR: Field config for #{name}: Type #{type}: Not a class") unless config[:type].is_a? Class

            # Define getters and setters for all fields by default
            # Preferring this pattern over attr_accessor/attr_reader to reduce boilerplate
            define_singleton_method(name) { instance_variable_get("@#{name}") } if config.fetch(:define_getter, self.class::GETTER_DEFAULT)
            # Default sets to off, it's expected that most fields will be static for the life of the object
            define_singleton_method("#{name}=") { |val| _set_attr(name, val) } if config.fetch(:define_setter, self.class::SETTER_DEFAULT)
          end

          # The constructor needs to take all the args, for from_json()
          args.each_pair do |name, val|
            _set_attr(name, val)
          end
        end

        def to_h
          self.class::FIELDS.keys.map { |name| [name, send(name)] }.to_h
        end
        
        def to_json(*args, **kwargs)
          to_h.to_json(*args, **kwargs)
        end

        private

        def _parse_value(value:, expected_type:)
          return value if value.is_a? expected_type

          # Nested Parsing
          return expected_type.new(**value.transform_keys(&:to_sym)) if value.is_a?(Hash)
          return value.to_sym if value.is_a?(String) && expected_type == Symbol
          
          raise(ArgumentError, "must be instance of #{expected_type}, got #{value.class}") unless value.is_a? Hash
        end

        def _set_attr(name, raw_value)
          raise(ArgumentError, "#{self.class}: INTERNAL ERROR: Unknown field #{name}") unless self.class::FIELDS[name]
          begin
            value = _parse_value(expected_type: self.class::FIELDS[name].fetch(:type), value: raw_value)
          rescue ArgumentError => exc
            raise(ArgumentError, "#{self.class}: #{name} #{exc}")
          end

          case value
          when Array
            raise(ArgumentError, "#{self.class}: INTERNAL ERROR: #{self.class::FIELDS[name].fetch(:type)} missing setting :val_type") unless self.class::FIELDS[name].key?(:val_type)

            value = value.map.with_index do |subval, index|
              _parse_value(expected_type: self.class::FIELDS[name][:val_type], value: subval)
            rescue ArgumentError => exc
              raise(ArgumentError, "#{self.class}: #{name} must be an array of #{self.class::FIELDS[name][:val_type]}, object at index #{index} is #{subval.class}")
            end

          when Hash
            raise(ArgumentError, "#{self.class}: INTERNAL ERROR: #{self.class::FIELDS[name].fetch(:type)} missing setting :key_type") unless self.class::FIELDS[name].key?(:key_type)
            raise(ArgumentError, "#{self.class}: INTERNAL ERROR: #{self.class::FIELDS[name].fetch(:type)} missing setting :val_type") unless self.class::FIELDS[name].key?(:val_type)

            value = value.map do |key, subval|
              begin
                parsed_key = _parse_value(expected_type: self.class::FIELDS[name][:key_type], value: key)
              rescue ArgumentError => exc
                raise(ArgumentError, "#{self.class}: #{name} must be a map of #{self.class::FIELDS[name][:key_type]} => #{self.class::FIELDS[name][:val_type]} pairs, #{name} is a #{name.class}") unless name.is_a?(self.class::FIELDS[name][:key_type])
              end

              begin
                parsed_value = _parse_value(expected_type: self.class::FIELDS[name][:val_type], value: subval)
              rescue ArgumentError => exc
                raise(ArgumentError, "#{self.class}: #{name} must be an array of #{self.class::FIELDS[name][:val_type]}, object at #{key} is #{subval.class}") unless subval.is_a?(self.class::FIELDS[name][:val_type])
              end

              [parsed_key, parsed_value]
            end.to_h
          end          

          instance_variable_set("@#{name}", value)
        end
      end
    end
  end
end
