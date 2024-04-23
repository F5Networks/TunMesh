#!/usr/bin/env ruby
# tun_handler: This program sets up the tun device and forwards all traffic to named pipes
# Requires access to the /dev/tun device, cap_net_admin, and cap_net_raw
# Minimal: Performs only the minimum abount of processing due to the high privilege level needed
# TODO: Can we clean up if we Process::UID.change_privilege()?

require 'logger'
require 'pathname'
require 'rb_tuntap'

require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/structs/net_address'
require './lib/tun_mesh/ipc/packet'
require './lib/tun_mesh/ipc/queue_manager'

def open_tunnel(logger:)
  begin
    logger.debug("Opening #{TunMesh::CONFIG.tun_device_name}")
    tun = RbTunTap::TunDevice.new(TunMesh::CONFIG.tun_device_name)
    tun.open(false)

    dev_ipaddr_obj = TunMesh::ControlPlane::Structs::NetAddress.parse_cidr(TunMesh::CONFIG.private_address_cidr)
    logger.debug("Configuring #{TunMesh::CONFIG.tun_device_name} address #{dev_ipaddr_obj.address}/#{dev_ipaddr_obj.netmask}")
    tun.addr    = dev_ipaddr_obj.address.to_s
    tun.netmask = dev_ipaddr_obj.netmask.to_s

    logger.debug("Bringing up #{TunMesh::CONFIG.tun_device_name}")
    tun.up

    logger.info("#{TunMesh::CONFIG.tun_device_name} open")

    yield tun
  ensure
    logger.debug("Closing #{TunMesh::CONFIG.tun_device_name}")
    tun.down
    tun.close
    logger.info("#{TunMesh::CONFIG.tun_device_name} closed")
  end
end

def process_traffic(logger:, queue_manager:, tun:)
  logger.debug("process_traffic() Entering")
  threads = []

  # TODO: This should be select() or something.
  threads.push(Thread.new do
                 loop do
                   begin
                     packet = TunMesh::IPC::Packet.from_json(queue_manager.tun_write.pop)
                     logger.debug { "Writing #{packet.id}: #{packet.data_length}b, #{Time.now.to_f - packet.stamp}s old" }
                     tun.to_io.write(packet.data)
                     tun.to_io.flush
                   rescue StandardError => exc
                     logger.warn { "Failed to write #{packet.id}: #{exc.class}: #{exc}" }
                   end
                 end
               end)

  threads.push(Thread.new do
    loop do
      raw_data = tun.to_io.sysread(tun.mtu)
      packet = TunMesh::IPC::Packet.new(data: raw_data)
      packet.stamp = Time.now.to_f
      logger.debug { "Read #{packet.id} #{packet.data_length}b" }
      queue_manager.tun_read.push(packet.to_json)
    rescue StandardError => exc
      logger.warn { "Failed to read tun device: #{exc.class}: #{exc}" }
    end
  end)

  loop do
    break unless threads.map(&:alive?).all?
    queue_manager.tun_heartbeat.push(Time.now.to_f)
    sleep(1) # TODO: Hardcode
  end

  logger.debug("process_traffic() Exiting")

  threads.each(&:terminate)
  threads.each(&:join)
  
  logger.debug("process_traffic() Complete")
end

def main
  logger = Logger.new(STDERR, progname: 'tun_handler')
  queue_manager = TunMesh::IPC::QueueManager.new(control: false) # Control = false: Queues are expected to exist

  # Ensure we can open the queue
  queue_manager.tun_read
  queue_manager.tun_write
  queue_manager.tun_heartbeat
  
  open_tunnel(logger: logger) do |tun|
    loop do
      process_traffic(logger: logger, queue_manager: queue_manager, tun: tun)

      logger.warn("process_traffic() exited")
      sleep(1)
    end
  end
end

# TODO if progname
main
