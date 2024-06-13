require 'rb_tuntap'

require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'
require './lib/tun_mesh/control_plane/structs/net_address'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/ipc/tun_monitor_metric'
require './lib/tun_mesh/ipc/queue_manager'

module TunMesh
  module VPN
    class TunHandler
      def initialize(queue_key:)
        @logger = TunMesh::Logger.new(id: self.class.to_s)
        @queue_manager = TunMesh::IPC::QueueManager.new(queue_key: queue_key)
      end

      def run!
        _open_tunnel do |tun|
          Process::UID.change_privilege(TunMesh::CONFIG.values.process.uid)
          loop do
            _process_traffic(tun: tun)

            @logger.warn('process_traffic() exited')
            sleep(TunMesh::CONFIG.values.process.timing.tun_handler.fault_delay)
          end
        end
      end

      private

      def _open_tunnel
        begin
          @logger.debug("Opening #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun = RbTunTap::TunDevice.new(TunMesh::CONFIG.values.networking.tun_device_id)
          tun.open(true)

          # TODO: IPv6 support
          # TODO: IPv6 Not supported upstream: https://github.com/amoghe/rb_tuntap/blob/master/lib/rb_tuntap.rb#L95-L97
          # TODO: Support shelling out to set up the interface.  This pattern will allow IPv6 and arbitrary extensions.

          # Open the device with the local address but the mesh subnet.
          # This will cause all mesh IPs to be sent to this process.
          # Local/mesh subnetting is done in software here.
          dev_ipaddr_obj = TunMesh::ControlPlane::Structs::NetAddress.parse_cidr(
            [
              TunMesh::CONFIG.values.networking[:ipv4].node_address_cidr.address,
              TunMesh::CONFIG.values.networking[:ipv4].network_cidr.prefix
            ].join('/')
          )

          @logger.debug("Configuring #{TunMesh::CONFIG.values.networking.tun_device_id} address #{dev_ipaddr_obj.address}/#{dev_ipaddr_obj.netmask}")
          tun.addr    = dev_ipaddr_obj.address.to_s
          tun.netmask = dev_ipaddr_obj.netmask.to_s

          @logger.debug("Bringing up #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun.up

          @logger.info("#{TunMesh::CONFIG.values.networking.tun_device_id} #{dev_ipaddr_obj.address}/#{dev_ipaddr_obj.netmask} open")

          yield tun
        ensure
          @logger.debug("Closing #{TunMesh::CONFIG.values.networking.tun_device_id}")
          tun.down
          tun.close
          @logger.info("#{TunMesh::CONFIG.values.networking.tun_device_id} closed")
        end
      end

      def _process_traffic(tun:)
        @logger.debug('_process_traffic() Entering')
        threads = []

        threads.push(Thread.new do
                       loop do
                         begin
                           packet = TunMesh::IPC::Packet.decode(@queue_manager.tun_write.pop)
                           break if packet.nil?
                         rescue Errno::EIDRM => exc
                           @logger.warn { "Queue shut down: #{exc.class}: #{exc}" }
                           break
                         rescue StandardError => exc
                           @logger.warn { "Failed to read tun_write packet: #{exc.class}: #{exc}" }
                           next
                         end

                         begin
                           latency = Time.now.to_f - packet.stamp
                           @logger.debug { "Writing #{packet.id}: #{packet.data_length}b, #{latency}s old" }
                           tun.to_io.write(packet.to_tun)
                           tun.to_io.flush
                         rescue StandardError => exc
                           @logger.warn { "Failed to write #{packet.id}: #{exc.class}: #{exc}" }
                           next
                         end

                         begin
                           next unless TunMesh::CONFIG.values.monitoring.enable_node_packet_metrics

                           @queue_manager.tun_monitor.push(IPC::TunMonitorMetric.new(source_node_id: packet.source_node_id, latency: latency).encode)
                         rescue StandardError => exc
                           @logger.warn { "Failed to metrics for write #{packet.id}: #{exc.class}: #{exc}" }
                           next
                         end
                       end
                     end)

        threads.push(Thread.new do
                       loop do
                         raw_data = tun.to_io.sysread(tun.mtu + 4) # +4 for the header
                         packet = TunMesh::IPC::Packet.from_tun(raw: raw_data, rx_stamp: Time.now.to_f)
                         @logger.debug { "Read #{packet.id} #{packet.data_length}b" }
                         @queue_manager.tun_read.push(packet.encode)
                       rescue Errno::EINVAL => exc
                         # This only happens under load, and is outside this code
                         # Root cause is unknown
                         # Log at debug level as it can flood out the terminal
                         @logger.debug { "Failed to read tun device: #{exc.class}: #{exc}" }
                         @logger.debug { exc.backtrace }
                       rescue StandardError => exc
                         @logger.warn { "Failed to read tun device: #{exc.class}: #{exc}" }
                         @logger.debug { exc.backtrace }
                       end
                     end)

        loop do
          break unless threads.map(&:alive?).all?

          @queue_manager.tun_heartbeat.push(Time.now.to_f)
          sleep(TunMesh::CONFIG.values.process.timing.tun_handler.heartbeat_interval)
        end

        @logger.debug('process_traffic() Exiting')

        threads.each(&:terminate)
        threads.each(&:join)

        @logger.debug('process_traffic() Complete')
      end
    end
  end
end
