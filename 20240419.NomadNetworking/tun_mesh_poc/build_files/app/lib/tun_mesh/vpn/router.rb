require 'logger'
require_relative 'vpn/packets/ipv4/packet'

module TunMesh
  module VPN
    class Router
      def initialize(manager:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @manager = manager

        @write_queue = Queue.new
        _read_pipe_thread
        _write_pipe_thread
      end

      def rx_remote_packet(packet:)
        _rx_packet(packet: packet, source: :remote)
      end

      # TODO: Health check
      
      private 

      def _read_pipe_thread
        @read_pipe_thread ||= Thread.new do
          # Tunnel read pipe is tunnel -> pipe
          TunMesh::NamedPipe.new(init_pipe: false, path: TunMesh::CONFIG.tun_write_pipe_path).read_loop do |packet|
            _rx_packet(packet: packet, source: :local)
          end
        end
      end
      
      def _route_local_packet(ipv4_obj:, packet:)
        if ipv4_obj.dest_address == 0xffffffff
          # TODO: Dropping because ... not ready to code the subnet check
          logger.warn("#{packet.md5}: Dropping packet from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} (Broadcast)")
          return
        end
        
        if ipv4_obj.dest_str == @manager.self_node_info.private_address.address
          logger.warn("Dropping packet from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} (Self) received local")
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
          logger.error("Dropping packet from #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str} received remote: Misrouted")
          return
        end

        @write_queue << packet
      end

      def _rx_packet(packet:, source:)
        raise(ArgumentError, "Expected TunMesh::NamedPipe::Packet, got #{packet.class}") unless packet.is_a? TunMesh::NamedPipe::Packet

        logger.debug("#{packet.md5}: Recieved a #{packet.data_length} byte packet with signature")
        if (packet.data[0].ord & 0xf0) != 0x40
          logger.debug("#{packet.md5}: Dropping: Not a IPv4 packet")
          return
        end

        ipv4_obj = Packet::IPv4::Packets.decode(packet.data)
        logger.debug { "#{packet.md5}: IPv4: #{ipv4_obj.source_str} -> #{ipv4_obj.dest_str}" }

        case source
        when :local
          _route_local_packet(ipv4_obj: ipv4_obj, packet: packet)
        when :remote
          _route_remote_packet(ipv4_obj: ipv4_obj, packet: packet)
        else
          raise("INTERNAL ERROR: unknown source #{source}")
        end
      end

      def _write_pipe_thread
        @write_pipe_thread ||= Thread.new do
          # Tunnel write is pipe -> tunnel
          TunMesh::NamedPipe.new(init_pipe: false, path: TunMesh::CONFIG.tun_write_pipe_path).write_loop do
            packet = @write_queue.pop
            logger.debug{"#{packet.md5}: Transmitting"}
            packet
          end
        end
      end
    end
  end
end
        
        
