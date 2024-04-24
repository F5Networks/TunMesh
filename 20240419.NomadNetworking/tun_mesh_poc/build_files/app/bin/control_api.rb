#!/usr/bin/env ruby
# This app exposes a TCP/HTTP listener for the control plane
# TCP is used because UDP does not play nice with Docker nat, and net=host mode is not an option in this application

require './lib/tun_mesh/control_plane/manager'

manager = TunMesh::ControlPlane::Manager.new
manager.run_api!
