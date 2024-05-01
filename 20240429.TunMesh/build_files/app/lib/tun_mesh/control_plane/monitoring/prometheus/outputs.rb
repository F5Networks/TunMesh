require 'prometheus/client'
require './lib/tun_mesh/config'
require_relative 'client/data_stores/synchronized_ttl'

module TunMesh
  module ControlPlane
    class Monitoring
      module Prometheus
        # This class is a central store for the Prometheus output objects
        # It is meant to be a single, persistent store as outputs can only be registered once.
        class Outputs
          attr_reader :base_labels, :registry

          def initialize(registry: ::Prometheus::Client.registry)
            @registry = registry

            # Use a custom data store that supports TTLs.
            # This is to allow ID specific labels, like pool members, to age out when they disappear upstream
            ::Prometheus::Client.config.data_store = TunMesh::ControlPlane::Monitoring::Prometheus::Client::DataStores::SynchronizedTTL.new(ttl: nil)

            @base_labels = {
              node_id: TunMesh::CONFIG.node_id
            }.merge(TunMesh::CONFIG.values.monitoring.prometheus.base_labels.transform_keys(&:to_sym))

            @outputs = {}
          end

          def add_gauge(docstring:, id:, initial_value: nil, labels: {}, ttl: nil)
            @outputs[id] = ::Prometheus::Client::Gauge.new(
              id,
              docstring: docstring,
              labels: _complete_labels(labels: labels).keys,
              store_settings: { ttl: ttl }
            )

            # This conditional is for test.  It allows specs to init this class with a null registry so we can repeadedly add the same gauge across multiple specs
            @registry.register(@outputs[id]) if @registry

            set_gauge(id: id, value: initial_value, labels: labels) unless initial_value.nil?
            return @outputs[id]
          end

          def add_histogram(docstring:, id:, labels: {}, ttl: nil)
            @outputs[id] = ::Prometheus::Client::Histogram.new(
              id,
              docstring: docstring,
              labels: _complete_labels(labels: labels).keys,
              store_settings: { ttl: ttl }
            )

            # This conditional is for test.  It allows specs to init this class with a null registry so we can repeadedly add the same histogram across multiple specs
            @registry.register(@outputs[id]) if @registry

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

          def update_histogram(id:, value:, labels: {})
            raise(ArgumentError, "Unknown monitor ID #{id}") unless @outputs.key?(id)

            @outputs[id].observe(value, labels: _complete_labels(labels: labels))
          end

          private

          def _complete_labels(labels:)
            return @base_labels.merge(labels.transform_keys(&:to_sym))
          end
        end
      end
    end
  end
end
