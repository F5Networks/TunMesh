require './lib/tun_mesh/config'
require_relative './monitoring/null_outputs'
require_relative './monitoring/prometheus_outputs'

module TunMesh
  module ControlPlane
    class Monitoring
      def initialize
        case TunMesh::CONFIG.values.monitoring.method
        when 'none'
          @outputs = NullOutputs.new
          return
        when 'prometheus'
          @outputs = PrometheusOutputs.new
        else
          raise("INTERNAL ERROR: Unknown monitoring method #{TunMesh::CONFIG.values.monitoring.method}")
        end

        @outputs.add_gauge(
          id: :start_stamp,
          docstring: "TunMesh: Start Stamp",
          initial_value: Time.now.to_i
        )

        @outputs.add_gauge(
          id: :dropped_packets,
          docstring: "TunMesh: Dropped packets",
          labels: {
            reason: nil
          }
        )

        @outputs.add_gauge(
          id: :remote_rx_packets,
          docstring: "TunMesh: Packets received from other nodes",
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :remote_tx_packets,
          docstring: "TunMesh: Packets sent to other nodes",
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :tun_rx_packets,
          docstring: "TunMesh: Packets received over the tun device",
          initial_value: 0
        )

        @outputs.add_gauge(
          id: :tun_tx_packets,
          docstring: "TunMesh: Packets sent over the tun device",
          initial_value: 0
        )
      end

      def increment_gauge(**kwargs)
        @outputs.increment_gauge(**kwargs)
      end

      def set_gauge(**kwargs)
        @outputs.set_gauge(**kwargs)
      end
    end
  end
end
