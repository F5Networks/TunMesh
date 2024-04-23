#!/usr/bin/env ruby
# tun_handler: This program sets up the tun device and forwards all traffic to named pipes
# Requires access to the /dev/tun device, cap_net_admin, and cap_net_raw
# Minimal: Performs only the minimum abount of processing due to the high privilege level needed

require 'logger'
require 'pathname'
require 'rb_tuntap'

require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/structs/net_address'

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

def process_traffic(logger:, tun:)
  write_thread = Thread.new do
    # Tunnel write is pipe -> tunnel
    TunMesh::NamedPipe.new(init_pipe: false, path: TunMesh::CONFIG.tun_write_pipe_path).read_loop do |packet|
      tun.to_io.write(packet.data)
    end      
  end

  # Tunnel read pipe is tunnel -> pipe
  TunMesh::NamedPipe.new(init_pipe: false, path: TunMesh::CONFIG.tun_read_pipe_path).write_loop do
    if write_thread.alive?
      # Read the mtu as this is a packet interface
      tun.to_io.sysread(tun.mtu)
    else
      # Exit if the write_thread is dead
      @logger.warn("Write thread dead, exiting reader")
      nil
    end
  end

  @logger.debug("process_traffic() exiting")
end

def main
  logger = Logger.new(STDERR, progname: 'tun_handler')
  open_tunnel(logger: logger) do |tun|
    loop do
      process_traffic(logger: logger, tun: tun)

      @logger.warn("process_traffic() exited")
      sleep(1)
    end
  end
end

# TODO if progname
main
