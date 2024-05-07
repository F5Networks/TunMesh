require_relative 'group'
require_relative 'types/enum'

module TunMesh
  class Config
    class Logging < Group
      def initialize
        super(
          key: 'logging',
          description_short: 'Application logging configuration'
        )

        add_field(
          Types::Enum.new(
            key: 'level',
            default: 'info',
            description_short: 'Application log level',
            allowed_values: {
              error: 'Handleable error conditions.',
              warn: 'Warnings about abnormal conditions.',
              info: 'Normal, informational logs.',
              debug: 'Detailed debugging information.',
            }
          )
        )
      end
    end
  end
end
