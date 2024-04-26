require 'logger'
require './lib/tun_mesh/ipc/packet'
require_relative '../api/client'
require_relative '../structs/registration'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNode
        attr_reader :api_client, :id, :registration
        
        def initialize(manager:, registration:, api_client: nil)
          @manager = manager
          @api_client = api_client
          @registration = registration

          @logger = Logger.new(STDERR, progname: "#{self.class}(#{id})")

          @transmit_queue = Queue.new
        end

        def api_client
          @api_client ||= @manager.api.new_client(remote_id: registration.local.id, remote_url: registration.local.listen_url)
        end
        
        def api_session_auth(rotate: false)
          return @api_session_auth if @api_session_auth && !rotate
          raise("Remote ID unknown, cannot instantiate auth") unless id

          @api_session_auth = Auth.new(
            id: id,
            manager: @manager,
            secret: Auth.random_secret
          )

          return api_session_auth
        end
        
        def close
          unless @transmit_queue.closed?
            @transmit_queue.close

            unless @transmit_queue.empty?
              pending_packets = @transmit_queue.length
              @logger.warn("Closing: Dropping #{@transmit_queue.length} messages")
              @manager.monitors.increment_gauge(id: :dropped_packets, by: pending_packets, labels: {reason: :node_close})
            end
          end

          _transmit_worker.terminate
        end

        def health
          rv = {
            registration: !stale?,
            transmit_queue: !@transmit_queue.closed?
          }

          # Only include transmit_worker stats if the worker is initialized
          # Worker is started on the first tx packet
          rv[:transmit_worker] = _transmit_worker.alive? if @transmit_worker

          return rv
        end

        def healthy?
          health.values.all?
        end

        def id
          @id ||= api_client.remote_id # This will get the ID if it is unknown
        end

        def node_info
          registration.local
        end

        def private_address
          node_info.private_address.address
        end
        
        def registration_required?
          # TODO: Hardcode
          (Time.now.to_i - stamp) > 5
        end

        def remotes
          registration.remote
        end
        
        def stale?
          # TODO: Hardcode
          (Time.now.to_i - stamp) > 30
        end
        
        def stamp
          registration.stamp
        end

        def to_json(*args, **kwargs)
          {
            node_info: node_info,
            stamp: stamp,
            stale: stale?
          }.to_json(*args, **kwargs)
        end

        def transmit_packet(packet:)
          raise("No worker") unless _transmit_worker.alive?
          @transmit_queue.push(packet)
        end

        def update_registration(new_registration)
          raise(ArgumentError, "new_registration not a Structs::Registration, got #{new_registration.class}") unless new_registration.is_a?(Structs::Registration)
          @api_client = nil unless new_registration.local.listen_url == @api_client&.remote_url

          raise("ID Mismatch #{id} / #{new_registration.local.id}") if id != new_registration.local.id
          # Changing IPs is not supported.  This breaks a caching assumptions in RemoteNodePool
          raise("Private address changed from #{private_address} to #{new_registration.local.private_address.address}") if private_address != new_registration.local.private_address.address

          @registration = new_registration
        end

        private

        def _transmit_worker
          @transmit_worker ||= Thread.new do
            @logger.debug("transmit_worker: Initialized")
            loop do
              break if @transmit_queue.closed?

              packet = @transmit_queue.pop
              break if packet.nil?

              begin
                raise("Expected TunMesh::IPC::Packet, popped #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

                # TODO: Hardcode
                packet_age = Time.now.to_f - packet.stamp
                if packet_age > 10
                  @logger.warn("Dropping packet #{packet.id}: Expired: #{packet_age}s old")
                  @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :expired})
                  next
                end
                
                api_client.transmit_packet(packet: packet)
                @logger.debug("Successfully transmitted #{packet.id}")
              rescue StandardError => exc
                @logger.warn("transmit_worker: Iteration caught exception: #{exc.class}: #{exc}")
                @logger.warn("Dropping packet #{packet.id}: Exception") if packet&.id
                @manager.monitors.increment_gauge(id: :dropped_packets, labels: {reason: :exception})
              end
            end
          ensure
            @logger.debug("transmit_worker: Exiting")
            @transmit_queue.close
          end
        end
      end
    end
  end
end
          
          
