require 'logger'
require './lib/tun_mesh/ipc/packet'
require_relative '../api/client'
require_relative '../structs/registration'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNode
        attr_reader :registration
        
        def initialize(manager:, registration:)
          @manager = manager
          @registration = registration
          @transmit_queue = Queue.new
        end

        def client
          @client ||= API::Client.new(manager: @manager, remote_url: registration.local.listen_url)
        end

        def close
          _logger.warn("Closing: Dropping #{@transmit_queue.length} messages") unless @transmit_queue.empty?
          @transmit_queue.close
          _transmit_worker.terminate
        end

        def health
          rv = {
            registration: !stale?,
            transmit_queue: !@transmit_queue.closed?,
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
          @registration&.local&.id
        end

        def node_info
          @registration.local
        end
        
        def registration_required?
          # TODO: Hardcode
          (Time.now.to_i - stamp) > 5
        end

        def remotes
          @registration.remote
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
          raise("ID Mismatch #{registration.local.id} / #{new_registration.local.id}") if registration.local.id != new_registration.local.id

          @client = nil
          @registration = new_registration
        end

        private

        def _logger
          return @logger if @logger
          
          if id
            @logger = Logger.new(STDERR, progname: "#{self.class}(#{id})")
            return @logger
          else
            return Logger.new(STDERR, progname: "#{self.class}([INITIALIZING])")
          end
        end
        
        def _transmit_worker
          @transmit_worker ||= Thread.new do
            _logger.debug("transmit_worker: Initialized")
            loop do
              break if @transmit_queue.closed?

              packet = @transmit_queue.pop
              break if packet.nil?

              begin
                raise("Expected TunMesh::IPC::Packet, popped #{packet.class}") unless packet.is_a? TunMesh::IPC::Packet

                # TODO: Hardcode
                packet_age = Time.now.to_f - packet.stamp
                if packet_age > 10
                  _logger.warn("Dropping packet #{packet.id}: Expired: #{packet_age}s old")
                  next
                end
                
                client.transmit_packet(packet: packet)
                _logger.debug("Successfully transmitted #{packet.id}")
              rescue StandardError => exc
                _logger.warn("transmit_worker: Iteration caught exception: #{exc.class}: #{exc}")
                _logger.warn("Dropping packet #{packet.id}: Exception") if packet&.id
              end
            end
          ensure
            _logger.debug("transmit_worker: Exiting")
            @transmit_queue.close
          end
        end
      end
    end
  end
end
          
          
