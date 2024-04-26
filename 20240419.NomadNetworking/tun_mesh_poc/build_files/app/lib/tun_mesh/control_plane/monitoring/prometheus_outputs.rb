require 'prometheus/client'
require './lib/tun_mesh/config'

module TunMesh
  module ControlPlane
    class Monitoring
      # This class is a central store for the Prometheus output objects
      # It is meant to be a single, persistent store as outputs can only be registered once.
      class PrometheusOutputs
        attr_reader :base_labels, :registry

        def initialize(registry: Prometheus::Client.registry)
          @registry = registry
          @base_labels = {
            # TODO: More config
            node_id: TunMesh::CONFIG.node_id
          }

          @outputs = {}
        end

        def add_gauge(docstring:, id:, initial_value: nil, labels: {})
          @outputs[id] = Prometheus::Client::Gauge.new(id, docstring: docstring, labels: _complete_labels(labels: labels).keys)

          # This conditional is for test.  It allows specs to init this class with a null registry so we can repeadedly add the same gauge across multiple specs
          @registry.register(@outputs[id]) if @registry

          set_gauge(id: id, value: initial_value, labels: labels) unless initial_value.nil?
          return @outputs[id]
        end

        def increment_gauge(id:, by: 1, labels: {})
          raise(ArgumentError, "Unknown monitor ID #{id}") unless @outputs.key?(id)

            @outputs[id].increment(
              by: by, # by
              labels: _complete_labels(labels: labels)
            )
        end
        
        def set_gauge(id:, value:, labels: {})
          raise(ArgumentError, "Unknown monitor ID #{id}") unless @outputs.key?(id)

          @outputs[id].set(value, labels: _complete_labels(labels: labels))
        end

        # This is used by test
        def get_gauge(id:, labels: {})
          raise(ArgumentError, "Unknown monitor ID #{id}") unless @outputs.key?(id)

          @outputs[id].get(labels: _complete_labels(labels: labels))
        end

        private

        def _complete_labels(labels:)
          return @base_labels.merge(labels.transform_keys(&:to_sym))
        end
      end
    end
  end
end
