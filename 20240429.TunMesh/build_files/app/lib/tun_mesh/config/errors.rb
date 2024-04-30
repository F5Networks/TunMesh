module TunMesh
  class Config
    module Errors
      class ParseError < StandardError
        attr_reader :key, :value

        def initialize(message, key: nil, value: nil)
          @key = key
          @value = value
          super(message)
        end

        def prefix_key(key:)
          @key = [key, @key].compact.join('/')
        end
      end

      class MissingKeyError < ParseError
      end

      class TypeError < ParseError
      end

      class UnknownKeyError < ParseError
      end

      class ValueError < ParseError
      end
    end
  end
end
