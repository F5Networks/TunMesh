require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'
require './lib/tun_mesh/ipc/tun_monitor_metric'
require_relative './monitoring/null_outputs'
require_relative './monitoring/prometheus/outputs'

module TunMesh
  module ControlPlane
    class Monitoring
      def initialize(queue_manager:)
        @logger = TunMesh::Logger.new(id: self.class.to_s)
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

        {
          tx: 'sent to',
          rx: 'received from'
        }.each_pair do |direction_key, direction_description|
          %w[packets bytes].each do |metric|
            @outputs.add_gauge(
              id: "remote_#{direction_key}_#{metric}".to_sym,
              docstring: "TunMesh: #{metric} #{direction_description} other nodes",
              initial_value: 0
            )

            @outputs.add_gauge(
              id: "tun_#{direction_key}_#{metric}".to_sym,
              docstring: "TunMesh: #{metric} #{direction_description} the tun device",
              initial_value: 0
            )
          end
        end

        return unless TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

        %w[packets bytes].each do |metric|
          @outputs.add_gauge(
            id: "remote_rx_#{metric}_by_source_node".to_sym,
            docstring: "TunMesh: #{metric} received from other nodes by source node",
            labels: {
              source_node_id: nil
            },
            ttl: TunMesh::CONFIG.values.monitoring.metric_ttl
          )

          @outputs.add_gauge(
            id: "remote_tx_#{metric}_by_dest_node".to_sym,
            docstring: "TunMesh: #{metric} sent to other nodes by dest node",
            labels: {
              dest_node_id: nil
            },
            ttl: TunMesh::CONFIG.values.monitoring.metric_ttl
          )
        end

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

      def record_remote_rx_packet(packet:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

        increment_gauge(id: :remote_rx_packets)
        increment_gauge(id: :remote_rx_bytes, by: packet.data_length)
        return unless TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

        increment_gauge(id: :remote_rx_packets_by_source_node, labels: { source_node_id: packet.source_node_id })
        increment_gauge(id: :remote_rx_bytes_by_source_node, by: packet.data_length, labels: { source_node_id: packet.source_node_id })
      end

      def record_remote_tx_packet(dest_node_id:, packet:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

        increment_gauge(id: :remote_tx_packets)
        increment_gauge(id: :remote_tx_bytes, by: packet.data_length)
        return unless TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

        increment_gauge(id: :remote_tx_packets_by_dest_node, labels: { dest_node_id: dest_node_id })
        increment_gauge(id: :remote_tx_bytes_by_dest_node, by: packet.data_length, labels: { dest_node_id: dest_node_id })
      end

      def record_tun_rx_packet(packet:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

        increment_gauge(id: :tun_rx_packets)
        increment_gauge(id: :tun_rx_bytes, by: packet.data_length)
      end

      def record_tun_tx_packet(packet:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

        increment_gauge(id: :tun_tx_packets)
        increment_gauge(id: :tun_tx_bytes, by: packet.data_length)
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
