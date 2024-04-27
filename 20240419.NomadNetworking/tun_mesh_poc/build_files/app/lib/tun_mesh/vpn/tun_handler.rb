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
          Process::UID.change_privilege(TunMesh::CONFIG.values.process.uid)
          loop do
            _process_traffic(tun: tun)
            
            @logger.warn("process_traffic() exited")
            sleep(TunMesh::CONFIG.values.process.timing.tun_handler.fault_delay)
          end
        end
      end

      private
      
      def _open_tunnel
        begin
          @logger.debug("Opening #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun = RbTunTap::TunDevice.new(TunMesh::CONFIG.values.networking.tun_device_id)
          tun.open(false)

          # TODO: IPv6 support
          dev_ipaddr_obj = TunMesh::CONFIG.values.networking[:ipv4].node_address_cidr
          @logger.debug("Configuring #{TunMesh::CONFIG.values.networking.tun_device_id} address #{dev_ipaddr_obj.address}/#{dev_ipaddr_obj.netmask}")
          tun.addr    = dev_ipaddr_obj.address.to_s
          tun.netmask = dev_ipaddr_obj.netmask.to_s

          @logger.debug("Bringing up #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun.up

          @logger.info("#{TunMesh::CONFIG.values.networking.tun_device_id} open")

          yield tun
        ensure
          @logger.debug("Closing #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun.down
          tun.close
          @logger.info("#{TunMesh::CONFIG.values.networking.tun_device_id} closed")
        end
      end

      def _process_traffic(tun:)
        @logger.debug("_process_traffic() Entering")
        threads = []

        threads.push(Thread.new do
                       loop do
                         begin
                           packet = TunMesh::IPC::Packet.decode(@queue_manager.tun_write.pop)
                           break if packet.nil?

                           @logger.debug { "Writing #{packet.id}: #{packet.data_length}b, #{Time.now.to_f - packet.stamp}s old" }
                           tun.to_io.write(packet.data)
                           tun.to_io.flush
                         rescue Errno::EIDRM => exc
                           @logger.warn { "Queue shut down: #{exc.class}: #{exc}" }
                           break
                         rescue StandardError => exc
                           if packet.nil?
                             @logger.warn { "Failed to read tun_write packet: #{exc.class}: #{exc}" }
                           else
                             @logger.warn { "Failed to write #{packet.id}: #{exc.class}: #{exc}" }
                           end
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
          sleep(TunMesh::CONFIG.values.process.timing.tun_handler.heartbeat_interval)
        end

        @logger.debug("process_traffic() Exiting")

        threads.each(&:terminate)
        threads.each(&:join)
        
        @logger.debug("process_traffic() Complete")
      end
    end
  end
end
