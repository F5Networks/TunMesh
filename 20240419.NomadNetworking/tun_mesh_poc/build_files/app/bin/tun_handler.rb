#!/usr/bin/env ruby
# tun_handler: This program sets up the tun device and forwards all traffic to named pipes
# Requires access to the /dev/tun device, cap_net_admin, and cap_net_raw
# Minimal: Performs only the minimum abount of processing due to the high privilege level needed

require './lib/tun_mesh/vpn/tun_handler'

TunMesh::VPN::TunHandler.new.run!
