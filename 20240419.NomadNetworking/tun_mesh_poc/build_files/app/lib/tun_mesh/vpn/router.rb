require 'logger'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/ipc/queue_manager'
require_relative 'packets/ipv4/packet'

module TunMesh
  module VPN
    class Router
      def initialize(manager:, queue_key:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager

        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
        @last_tun_heartbeat = 0

        _read_pipe_thread
        _heartbeat_thread
      end

      def rx_remote_packet(packet_json:)
        packet = TunMesh::IPC::Packet.from_json(packet_json)
        _rx_packet(packet: packet, source: :remote)
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
      
      def _route_local_packet(ipv4_obj:, packet:)
        if ipv4_obj.dest_address == 0xffffffff
          # TODO: Dropping because ... not ready to code the subnet check
          @logger.warn { "Dropping packet #{packet.id} from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} (Broadcast)" }
          return
        end
        
        if ipv4_obj.dest_str == @manager.self_node_info.private_address.address
          @logger.warn("Dropping packet #{packet.id} from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} (Self) received local")
          return
        end

        @manager.transmit_packet(dest_addr: ipv4_obj.dest_str, packet: packet)
      end

      def _route_remote_packet(ipv4_obj:, packet:)
        if ipv4_obj.dest_address == 0xffffffff
          @manager.receive_packet(packet: packet)
          return
        end
        
        if ipv4_obj.dest_str != @manager.self_node_info.private_address.address
          @logger.error("Dropping packet #{packet.id} from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} received remote: Misrouted")
          return
        end

        unless tun_healthy?
          # This is a protection against filling up the queue if the other end is down.
          @logger.error("Dropping packet #{packet.id} from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} received remote: Tun unhealthy")
          return
        end

        @queue_manager.tun_write.push(packet.encode)
      end

      def _rx_packet(packet:, source:)
        raise(ArgumentError, "Expected TunMesh::IPC::Packet, got #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

        @logger.debug { "#{packet.id}: Recieved a #{packet.data_length} byte packet with signature #{packet.md5} from #{source}" }
        if (packet.data[0].ord & 0xf0) != 0x40
          @logger.debug { "#{packet.id}: Dropping: Not a IPv4 packet (0x#{packet.data[0].ord.to_s(16)})" }
          return
        end

        ipv4_obj = Packets::IPv4::Packet.decode(packet.data)
        @logger.debug { "#{packet.id}: IPv4: #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str}" }

        case source
        when :local
          _route_local_packet(ipv4_obj: ipv4_obj, packet: packet)
        when :remote
          _route_remote_packet(ipv4_obj: ipv4_obj, packet: packet)
        else
          raise("INTERNAL ERROR: unknown source #{source}")
        end
      end
    end
  end
end
