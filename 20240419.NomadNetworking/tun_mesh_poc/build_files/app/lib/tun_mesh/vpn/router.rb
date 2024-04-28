require 'logger'
require './lib/tun_mesh/config'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/ipc/queue_manager'
require_relative 'packets/ipv4/packet'

module TunMesh
  module VPN
    class Router
      DECODED_PACKET = Struct.new(:net_packet, :proto)
      
      def initialize(manager:, queue_key:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager

        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
        @last_tun_heartbeat = 0

        _read_pipe_thread
        _heartbeat_thread
      end

      def rx_remote_packet(packet_json:, source:)
        packet = TunMesh::IPC::Packet.from_json(packet_json)
        @manager.monitors.increment_gauge(id: :tun_rx_packets)
        _rx_packet(packet: packet, source: source)
      end

      def health
        return {
          read_pipe_thread: _read_pipe_thread.alive?,
          heartbeat_thread: _heartbeat_thread.alive?,
          tun: tun_healthy?
        }
      end
      
      def healthy?
        health_snapshot = health
        return true if health_snapshot.values.all?

        @logger.error("Unhealthy: #{health_snapshot}")
        return false
      end        

      def tun_healthy?
        if @last_tun_heartbeat == 0
          @logger.error("Tunnel process unhealthy: No heartbeat")
          return false
        end
        
        last_heartbeat = (Time.now.to_i - @last_tun_heartbeat) 
        return true if (last_heartbeat < 2.0)

        @logger.error("Tunnel process unhealthy: Last heartbeat #{last_heartbeat}s ago")
        return false
      end

      private

      def _decode_packet(packet:, source:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet
        
        @logger.debug { "#{packet.id}: Recieved a #{packet.data_length} byte packet with signature #{packet.md5} from #{source}" }
        if (packet.data[0].ord & 0xf0) == 0x40
          ipv4_obj = Packets::IPv4::Packet.decode(packet.data)
          @logger.debug { "#{packet.id}: IPv4: #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str}" }

          return DECODED_PACKET.new(
                   net_packet: ipv4_obj,
                   proto: :ipv4
                 )
        end
            
          
        @logger.debug { "#{packet.id}: Dropping: Not a known protocol (0x#{packet.data[0].ord.to_s(16)})" }
        @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :unknown_proto})
        return
      end

      # Separate thread to prevent the heartbeat queue from filling up
      def _heartbeat_thread
        @heartbeat_thread ||= Thread.new do
          loop do
            @last_tun_heartbeat = @queue_manager.tun_heartbeat.pop.to_f
          end
        end
      end
          
      def _read_pipe_thread
        @read_pipe_thread ||= Thread.new do
          loop do
            begin
              packet = TunMesh::IPC::Packet.decode(@queue_manager.tun_read.pop)
              _rx_packet(packet: packet, source: :local)
            rescue StandardError => exc
              @logger.error("Failed to process packet from tun_read queue: #{exc.class}: #{exc}")
              @logger.debug(exc.backtrace)
            end
          end
        end
      end
      
      def _route_local_packet(decoded_packet:, packet:)
        if decoded_packet.net_packet.dest_str == TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.address
          @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} (Self) received local")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :loopback})
          return
        end

        # Check local broadcast first because of IPv4 255.255.255.255
        if TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.broadcast?(decoded_packet.net_packet.dest_str)
          if TunMesh::CONFIG.values.networking[decoded_packet.proto].enable_broadcast
            if TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.include?(decoded_packet.net_packet.dest_str)
              # Broadcast to the local broadcast address is not supported, as the tun device is configured with the mesh netmask to get all the traffic for the mesh
              # Sending a local network broadcast address packet to the remote node will appear as a regular unicast dest IP to the receiving kernel
              # This is a implementation limitation.
              @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} (Self): Local Broadcast to subnet broadcast address not supported")
              @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :unsupported})
              return
            end

            @logger.info("Packet #{packet.id}: Broadcast packet to the local subnet")
            @manager.registrations.nodes_by_proto(proto: decoded_packet.proto).select do |remote_node|
              TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.include?(remote_node.node_addresses[decoded_packet.proto])
            end.each do |remote_node|
              _tx_packet(decoded_packet: decoded_packet, packet: packet, remote_node: remote_node)
            end
            
            return
          else
            @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} (Self): Local Broadcast (Disabled)")
            @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :config_prohibited})
            return
          end
        end
        
        unless TunMesh::CONFIG.values.networking[decoded_packet.proto].network_cidr.include?(decoded_packet.net_packet.dest_str)
          @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} (Self) Outside configured network")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :outside_configured_network})
          return
        end

        remote_node = @manager.registrations.node_by_address(proto: decoded_packet.proto, address: decoded_packet.net_packet.dest_str)
        if remote_node
          _tx_packet(decoded_packet: decoded_packet, packet: packet, remote_node: remote_node)
          return
        end

        if TunMesh::CONFIG.values.networking[decoded_packet.proto].network_cidr.broadcast?(decoded_packet.net_packet.dest_str)
          if TunMesh::CONFIG.values.networking[decoded_packet.proto].enable_broadcast
            @logger.info("Packet #{packet.id}: Broadcast packet to the routed subnet")
            @manager.registrations.nodes_by_proto(proto: decoded_packet.proto).each do |remote_node|
              _tx_packet(decoded_packet: decoded_packet, packet: packet, remote_node: remote_node)
            end

            return
          else
            @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} (Self): WAN Broadcast (Disabled)")
            @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :config_prohibited})
            return
          end
        end

        @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str}: Destination #{decoded_packet.proto} #{decoded_packet.net_packet.dest_str} unknown")
        @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :no_route})
        return
      end

      def _route_remote_packet(decoded_packet:, packet:, source:)
        source_node_obj = @manager.registrations.node_by_address(proto: decoded_packet.proto, address: decoded_packet.net_packet.source_str)
        unless source_node_obj
          @logger.error("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} received remote: Unknown source node")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :no_return_route})
          return
        end

        if decoded_packet.net_packet.dest_str == TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.address
          _rx_remote_packet_to_tun(decoded_packet: decoded_packet, packet: packet, source: source, source_node_obj: source_node_obj)
          return
        end

        if TunMesh::CONFIG.values.networking[decoded_packet.proto].node_address_cidr.broadcast?(decoded_packet.net_packet.dest_str)
          if TunMesh::CONFIG.values.networking[decoded_packet.proto].enable_broadcast
            @logger.debug("Packet #{packet.id}: Broadcast packet to the local subnet") 
            _rx_remote_packet_to_tun(decoded_packet: decoded_packet, packet: packet, source: source, source_node_obj: source_node_obj)
            return
          else
            @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str}: Local Broadcast (Disabled)")
            @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :config_prohibited})
            return
          end
        end
        
        if TunMesh::CONFIG.values.networking[decoded_packet.proto].network_cidr.broadcast?(decoded_packet.net_packet.dest_str)
          if TunMesh::CONFIG.values.networking[decoded_packet.proto].enable_broadcast
            @logger.debug("Packet #{packet.id}: Broadcast packet to the routed subnet")
            _rx_remote_packet_to_tun(decoded_packet: decoded_packet, packet: packet, source: source, source_node_obj: source_node_obj)
            return
          else
            @logger.warn("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str}: WAN Broadcast (Disabled)")
            @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :config_prohibited})
            return
          end
        end
        
        @logger.error("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} received remote: Misrouted")
        @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :misrouted})
        return
      end

      def _rx_packet(packet:, source:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet
        decoded_packet = _decode_packet(packet: packet, source: source)
        return unless decoded_packet

        if source == :local
          _route_local_packet(decoded_packet: decoded_packet, packet: packet)
        else
          _route_remote_packet(decoded_packet: decoded_packet, packet: packet, source: source)
        end
      end

      def _rx_remote_packet_to_tun(decoded_packet:, packet:, source:, source_node_obj:)
        source_id_by_dest_ip = source_node_obj.id
        if source_id_by_dest_ip != source
          @logger.error("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} received remote: Recieved from #{source} but route to dest is to #{source_id_by_dest_ip}")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :route_conflict})
          return
        end

        unless tun_healthy?
          # This is a protection against filling up the queue if the other end is down.
          @logger.error("Dropping packet #{packet.id} from #{decoded_packet.net_packet.source_str} -> #{decoded_packet.net_packet.dest_str} received remote: Tun unhealthy")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :tun_issue})
          return
        end

        @queue_manager.tun_write.push(packet.encode)
        @manager.monitors.increment_gauge(id: :tun_tx_packets)
      end

      def _tx_packet(decoded_packet:, packet:, remote_node:)
        @logger.debug { "TX: Transmitting packet #{packet.id} to #{remote_node.node_info.id} / #{decoded_packet.proto} #{decoded_packet.net_packet.dest_str}" }
        remote_node.transmit_packet(packet: packet)
        @manager.monitors.increment_gauge(id: :remote_tx_packets)
      end
    end
  end
end
