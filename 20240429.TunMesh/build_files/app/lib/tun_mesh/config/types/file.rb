require_relative '../errors'

module TunMesh
  class Config
    module Types
      class File < Base
        attr_reader :required

        def initialize(**kwargs)
          super

          @required = kwargs.fetch(:required, default.nil?)
        end

        def description_type
          'file path'
        end

        def load_config_value(value:, config_obj:)
          @value = config_obj.config_path.dirname.join(value)

          raise(Errors::ValueError.new('Does not exist', value: @value)) unless @value.exist?
          raise(Errors::ValueError.new('Is not a file', value: @value)) unless @value.file?
        end
      end
    end
  end
end
