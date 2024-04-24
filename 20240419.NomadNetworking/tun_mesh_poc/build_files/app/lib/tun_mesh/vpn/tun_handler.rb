require 'logger'
require 'rb_tuntap'

require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/structs/net_address'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/ipc/queue_manager'

module TunMesh
  module VPN
    class TunHandler
      def initialize(queue_key:)
        @logger = Logger.new(STDERR, progname: self.class.to_s)
        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
      end
      
      def run!
        _open_tunnel do |tun|
          Process::UID.change_privilege(100010) # TODO: hardcode
          loop do
            _process_traffic(tun: tun)
            
            @logger.warn("process_traffic() exited")
            sleep(1) # TODO: hardcode
          end
        end
      end

      private
      
      def _open_tunnel
        begin
          @logger.debug("Opening #{TunMesh::CONFIG.tun_device_name}")
          tun = RbTunTap::TunDevice.new(TunMesh::CONFIG.tun_device_name)
          tun.open(false)

          dev_ipaddr_obj = TunMesh::ControlPlane::Structs::NetAddress.parse_cidr(TunMesh::CONFIG.private_address_cidr)
          @logger.debug("Configuring #{TunMesh::CONFIG.tun_device_name} address #{dev_ipaddr_obj.address}/#{dev_ipaddr_obj.netmask}")
          tun.addr    = dev_ipaddr_obj.address.to_s
          tun.netmask = dev_ipaddr_obj.netmask.to_s

          @logger.debug("Bringing up #{TunMesh::CONFIG.tun_device_name}")
          tun.up

          @logger.info("#{TunMesh::CONFIG.tun_device_name} open")

          yield tun
        ensure
          @logger.debug("Closing #{TunMesh::CONFIG.tun_device_name}")
          tun.down
          tun.close
          @logger.info("#{TunMesh::CONFIG.tun_device_name} closed")
        end
      end

      def _process_traffic(tun:)
        @logger.debug("_process_traffic() Entering")
        threads = []

        # TODO: This should be select() or something.
        threads.push(Thread.new do
                       loop do
                         begin
                           packet = TunMesh::IPC::Packet.decode(@queue_manager.tun_write.pop)
                           @logger.debug { "Writing #{packet.id}: #{packet.data_length}b, #{Time.now.to_f - packet.stamp}s old" }
                           tun.to_io.write(packet.data)
                           tun.to_io.flush
                         rescue StandardError => exc
                           @logger.warn { "Failed to write #{packet.id}: #{exc.class}: #{exc}" }
                         end
                       end
                     end)

        threads.push(Thread.new do
                       loop do
                         raw_data = tun.to_io.sysread(tun.mtu)
                         packet = TunMesh::IPC::Packet.new(data: raw_data)
                         packet.stamp = Time.now.to_f
                         @logger.debug { "Read #{packet.id} #{packet.data_length}b" }
                         @queue_manager.tun_read.push(packet.encode)
                       rescue StandardError => exc
                         @logger.warn { "Failed to read tun device: #{exc.class}: #{exc}" }
                       end
                     end)

        loop do
          break unless threads.map(&:alive?).all?
          @queue_manager.tun_heartbeat.push(Time.now.to_f)
          sleep(1) # TODO: Hardcode
        end

        @logger.debug("process_traffic() Exiting")

        threads.each(&:terminate)
        threads.each(&:join)
        
        @logger.debug("process_traffic() Complete")
      end
    end
  end
end
