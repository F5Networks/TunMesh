require_relative 'base'
require_relative '../errors'

module TunMesh
  class Config
    module Types
      # This class is intended as a base class for types that store multiple primitive types, like arrays and hashes
      class MultiBase < Base
        attr_reader :allow_empty

        def initialize(**kwargs)
          @init_kwargs = kwargs
          @value_type = kwargs.fetch(:value_type)

          @allow_empty = kwargs.fetch(:allow_empty, required)
          # For templating where no values means nothing rendered, treat nil as empty
          @allow_nil = kwargs.fetch(:allow_nil, allow_empty)

          super
        end

        def default_description
          nil
        end

        def required
          @init_kwargs.fetch(:required, true)
        end
      end
    end
  end
end
