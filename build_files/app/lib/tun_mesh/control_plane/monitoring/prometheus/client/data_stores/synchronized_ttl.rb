module TunMesh
  module ControlPlane
    class Monitoring
      module Prometheus
        module Client
          module DataStores
            # Extension of the upstream Synchronized data store
            # The same basic behavior is the same, except each metric has a stamp, refreshed on update.
            # If the metric is not updated before the stamp expires, the metric is dropped.
            # Intended for use with metrics that use unique and volatile labels.
            class SynchronizedTTL
              def initialize(**store_settings)
                @store_settings = store_settings
              end

              # Unused arguments are required per the Prometheus::Client API specs
              # rubocop: disable Lint/UnusedMethodArgument
              def for_metric(metric_name, metric_type:, metric_settings: {})
                # We don't need `metric_type` for this particular store
                MetricStore.new(**@store_settings.merge(metric_settings))
              end
              # rubocop: enable Lint/UnusedMethodArgument

              # This is the core Prometheus::Client::DataStores::SynchronizedTTL storage object.
              class MetricStore
                def initialize(ttl:, flush_frequency: 300)
                  @flush_frequency = flush_frequency
                  @ttl = ttl

                  @metric_store = Hash.new { |hash, key| hash[key] = 0.0 }
                  @ttl_store = {}
                  @lock = ::Monitor.new

                  _flush_thread unless @ttl.nil?
                end

                def synchronize(&block)
                  @lock.synchronize(&block)
                end

                def set(labels:, val:)
                  synchronize do
                    @metric_store[labels] = val.to_f
                    @ttl_store[labels] = Time.now.to_f
                  end
                end

                def increment(labels:, by: 1)
                  synchronize do
                    @metric_store[labels] += by
                    @ttl_store[labels] = Time.now.to_f
                  end
                end

                def get(labels:)
                  synchronize do
                    @metric_store[labels]
                  end
                end

                def all_values
                  synchronize { @metric_store.dup }
                end

                private

                def _flush_thread
                  @flush_thread ||= Thread.new do
                    loop do
                      sleep(@flush_frequency)

                      threshold_stamp = Time.now.to_i - @ttl
                      delete_targets = @ttl_store.select { |_, stamp| stamp < threshold_stamp }.keys
                      synchronize do
                        @metric_store.delete_if { |labels| delete_targets.include?(labels) }
                        @ttl_store.delete_if { |labels| delete_targets.include?(labels) }
                      end
                    rescue StandardError => exc
                      warn("DataStores::SynchronizedTTL Failed to flush: #{exc.class}: #{exc}")
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
