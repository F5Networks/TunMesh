require './lib/tun_mesh/config'
require './lib/tun_mesh/logger'
require './lib/tun_mesh/ipc/packet'
require_relative '../api/auth/session'
require_relative '../api/client'
require_relative '../structs/registration'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNode
        attr_reader :api_client, :registration

        def initialize(manager:, registration:, api_client: nil)
          @manager = manager
          @api_client = api_client
          update_registration(registration)

          @logger = TunMesh::Logger.new(id: "#{self.class}(#{id})")

          @transmit_queue = Queue.new
        end

        def auth_session
          @auth_session ||= TunMesh::ControlPlane::API::Auth::Session.new(api_client: api_client, id: id)
        end

        def close
          unless @transmit_queue.closed?
            @transmit_queue.close

            unless @transmit_queue.empty?
              pending_packets = @transmit_queue.length
              @logger.warn("Closing: Dropping #{@transmit_queue.length} messages")
              @manager.monitors.increment_gauge(id: :dropped_packets, by: pending_packets, labels: { reason: :node_close })
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
          raise("ID Mismatch #{@id} / #{api_client.remote_id}") if @id && @id != api_client.remote_id

          @id ||= api_client.remote_id # This will get the ID if it is unknown
        end

        def local?
          node_addresses.each do |proto, node_address|
            return true if TunMesh::CONFIG.values.networking[proto].node_address_cidr.include?(node_address)
          end

          return false
        end

        def node_info
          registration.local
        end

        def node_addresses
          _node_addresses(tgt_registration: registration)
        end

        def registration_required?
          (Time.now.to_i - stamp) > TunMesh::CONFIG.values.process.timing.registrations[_timing_config_key].reregistration_interval
        end

        def remotes
          registration.remote
        end

        def stale?
          (Time.now.to_i - stamp) > TunMesh::CONFIG.values.process.timing.registrations[_timing_config_key].stale_threshold
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
          raise('No worker') unless _transmit_worker.alive?
          raise("Expected TunMesh::IPC::Packet, popped #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

          @transmit_queue.push(packet)
        end

        def update_registration(new_registration)
          raise(ArgumentError, "new_registration not a Structs::Registration, got #{new_registration.class}") unless new_registration.is_a?(Structs::Registration)

          @api_client = @manager.api.new_client(remote_url: new_registration.local.listen_url) unless new_registration.local.listen_url == @api_client&.remote_url
          raise("ID Mismatch #{id} / #{new_registration.local.id}") if id != new_registration.local.id

          if @registration
            # Changing IPs is not supported.  This breaks a caching assumptions in RemoteNodePool
            new_node_addresses = _node_addresses(tgt_registration: new_registration)
            raise("Node addresses changed from #{node_addresses} to #{new_node_addresses}") if node_addresses != new_node_addresses
          end

          @registration = new_registration
        end

        private

        def _node_addresses(tgt_registration:)
          tgt_registration.local.node_addresses.to_h.transform_values(&:address)
        end

        def _packet_expired?(packet:)
          packet_age = Time.now.to_f - packet.stamp
          return false if packet_age <= TunMesh::CONFIG.values.process.timing.network[_timing_config_key].packet_expiration

          @logger.warn("Dropping packet #{packet.id}: Expired: #{packet_age}s old")
          @manager.monitors.increment_gauge(id: :dropped_packets, labels: { reason: :expired })
          return true
        end

        def _timing_config_key
          return @timing_config if @timing_config

          if local?
            @timing_config = :local
          else
            @timing_config = :mesh
          end

          return @timing_config
        end

        def _transmit_worker
          @transmit_worker ||= Thread.new do
            @logger.debug { 'transmit_worker: Initialized' }
            loop do
              break if @transmit_queue.closed?

              packets = []
              packets.push(@transmit_queue.pop)
              break if packets[0].nil?
              next if _packet_expired?(packet: packets[0])

              # Load the remainder of the batch
              (TunMesh::CONFIG.values.control_api.max_batch_size - 1).times do
                begin
                  packet = @transmit_queue.pop(true)
                  next if _packet_expired?(packet: packet)

                  packets.push(packet)
                rescue ThreadError
                  # "If non_block is true, the thread isn't suspended, and ThreadError is raised."
                  break
                end
              end

              @logger.debug { "transmit_worker: Popped #{packets.length} packets off the queue" }

              begin
                if packets.length == 1
                  # Use the lower overhead path for a single packet
                  # This is the pre-batch support path, kept for compatibility
                  api_client.transmit_packet(packet: packets[0])
                  @logger.debug { "Successfully transmitted #{packets[0].id}" }
                else
                  api_client.transmit_packet_batch(packets: packets)
                  @logger.debug { "Successfully transmitted #{packets.length} packet batch: #{packets.map(&:id).join(',')}" }
                end

                packets.each do |packet|
                  @manager.monitors.record_remote_tx_packet(dest_node_id: id, packet: packet)
                end
              rescue StandardError => exc
                @logger.warn("transmit_worker: Iteration caught exception: #{exc.class}: #{exc}")
                @logger.debug { exc.backtrace }

                packets.each do |packet|
                  @logger.warn("Dropping packet #{packet.id}: Exception") if packet&.id
                  @manager.monitors.increment_gauge(id: :dropped_packets, labels: { reason: :exception })
                end
              end
            end
          ensure
            @logger.debug { 'transmit_worker: Exiting' }
            @transmit_queue.close
          end
        end
      end
    end
  end
end
