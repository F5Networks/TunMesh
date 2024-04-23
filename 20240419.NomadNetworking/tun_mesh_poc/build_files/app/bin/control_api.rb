#!/usr/bin/env ruby
# This app exposes a TCP/HTTP listener for the control plane
# TCP is used because UDP does not play nice with Docker nat, and net=host mode is not an option in this application

require 'sinatra'
require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/manager'

control_plane_manager = TunMesh::ControlPlane::Manager.new

set :bind, '0.0.0.0'
set :port, TunMesh::CONFIG.control_listen_port

post '/tunmesh/control/v0/packet/rx' do
  if env['CONTENT_TYPE'] == 'application/json'
    registration = control_plane_manager.receive_packet(packet_json: request.body.read)
    status 204
  else
    status 400
    content_type 'text/plain'
    body "Invalid content type #{env['CONTENT_TYPE']}"
  end
end

post '/tunmesh/control/v0/registrations/register' do
  if env['CONTENT_TYPE'] == 'application/json'
    begin
      registration = control_plane_manager.registrations.process_registration(request.body.read)

      status 200
      # Respond with our own info, to allow for a two way sync
      content_type 'application/json'
      body control_plane_manager.registrations.outbound_registration_payload.to_json
    rescue TunMesh::ControlPlane::Registrations::RegistrationFromSelf
      status 421
      content_type 'text/plain'
      body "Registration to self"
    end
  else
    status 400
    content_type 'text/plain'
    body "Invalid content type #{env['CONTENT_TYPE']}"
  end
end


    
    
