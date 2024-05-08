require 'logger'
require './lib/tun_mesh/config'
require './lib/tun_mesh/ipc/tun_monitor_metric'
require_relative './monitoring/null_outputs'
require_relative './monitoring/prometheus/outputs'

module TunMesh
  module ControlPlane
    class Monitoring
      def initialize(queue_manager:)
        @logger = Logger.new($stderr, level: TunMesh::CONFIG.values.logging.level, progname: self.class.to_s)
        @queue_manager = queue_manager
        _tun_monitor_worker if TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

        case TunMesh::CONFIG.values.monitoring.method
        when 'none'
          @outputs = NullOutputs.new
          return
        when 'prometheus'
          @outputs = Prometheus::Outputs.new
        else
          raise("INTERNAL ERROR: Unknown monitoring method #{TunMesh::CONFIG.values.monitoring.method}")
        end

        @outputs.add_gauge(
          id: :start_stamp,
          docstring: 'TunMesh: Start Stamp',
          initial_value: Time.now.to_i
        )

        @outputs.add_gauge(
          id: :dropped_packets,
          docstring: 'TunMesh: Dropped packets',
          labels: {
            reason: nil
          }
        )

        @outputs.add_gauge(
          id: :remote_rx_packets,
          docstring: 'TunMesh: Packets received from other nodes',
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :remote_tx_packets,
          docstring: 'TunMesh: Packets sent to other nodes',
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :tun_rx_packets,
          docstring: 'TunMesh: Packets received over the tun device',
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :tun_tx_packets,
          docstring: 'TunMesh: Packets sent over the tun device',
          initial_value: 0
        )

        return unless TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

        @outputs.add_gauge(
          id: :remote_tx_packets_by_source_node,
          docstring: 'TunMesh: Packets sent to other nodes by source node',
          labels: {
            source_node_id: nil
          },
          ttl: TunMesh::CONFIG.values.monitoring.metric_ttl
        )

        @outputs.add_histogram(
          id: :tun_packet_latency_by_source_node,
          docstring: 'TunMesh: Packet latency by source node',
          labels: {
            source_node_id: nil
          },
          ttl: TunMesh::CONFIG.values.monitoring.metric_ttl
        )
      end

      def health
        {
          tun_monitor_worker: (TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics || _tun_monitor_worker.alive?)
        }
      end

      def healthy?
        health.values.all?
      end

      def increment_gauge(**kwargs)
        @outputs.increment_gauge(**kwargs)
      end

      def set_gauge(**kwargs)
        @outputs.set_gauge(**kwargs)
      end

      def update_histogram(**kwargs)
        @outputs.update_histogram(**kwargs)
      end

      private

      def _tun_monitor_worker
        @tun_monitor_worker ||= Thread.new do
          loop do
            metric = IPC::TunMonitorMetric.decode(@queue_manager.tun_monitor.pop)
            @logger.debug { "Tun monitor: RX Metric Packet: #{metric.source_node_id} #{metric.latency}s" }

            update_histogram(
              id: :tun_packet_latency_by_source_node,
              value: metric.latency,
              labels: { source_node_id: metric.source_node_id }
            )
          rescue StandardError => exc
            @logger.error { "Tun monitor failed to process metrics: #{exc.class}: #{exc}" }
          end
        end
      end
    end
  end
end
