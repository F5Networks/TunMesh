require_relative '../group'
require_relative '../types/hash'
require_relative '../types/string'
require_relative '../types/timing'

module TunMesh
  class Config
    class Monitoring < Group
      class Prometheus < Group
        def initialize
          super(
            key: 'prometheus',
            description_short: 'Prometheus monitoring settings',
            description_long: 'Only used when method is prometheus'
          )

          add_field(
            Types::Hash.new(
              key: 'base_labels',
              required: false,
              value_type: Types::String,
              description_short: 'Map of labels to add to all metrics',
              description_long: <<~EOF
                Intended for adding environment labels like environment name
                The process node_id will be added automatically as a base label by default.
              EOF
            )
          )
        end
      end
    end
  end
end
