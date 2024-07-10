require './lib/tun_mesh/logger'
require_relative 'remote_node'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNodePool
        attr_reader :node_ids_by_address

        def initialize(manager:)
          @logger = TunMesh::Logger.new(id: self.class.to_s)
          @manager = manager
          @nodes = {}

          @node_lookup_lock = Mutex.new
          @node_ids_by_address = Hash.new { |h, k| h[k] = {} }
          @node_ids_by_address_lock = Mutex.new
        end

        def empty?
          @nodes.empty?
        end

        def groom!
          @node_lookup_lock.synchronize do
            @nodes.delete_if do |node_id, node|
              if node_id != node.id
                @logger.error("Node ID mismatch found: #{node_id} / #{node.id}")
                _finalize_node(id: node_id)
                _finalize_node(id: node.id)
                true
              elsif node.stale?
                @logger.warn("Removing stale node #{node_id}")
                _finalize_node(id: node_id)
                true
              elsif node.healthy?
                false
              else
                @logger.warn("Removing unhealthy node #{node_id}: #{node.health}")
                _finalize_node(id: node_id)
                true
              end
            end
          end
        end

        def id?(id)
          @nodes.key?(id)
        end

        def ids
          @nodes.keys
        end

        def node_by_address(**kwargs)
          return _node_by_id_safe(node_id: node_id_by_address(**kwargs))
        rescue StandardError => exc
          raise("INTERNAL ERROR: Node address lookup for #{kwargs} failed: #{exc.class}: #{exc}")
        end

        def node_by_id(id)
          @nodes[id]
        end

        def node_id_by_address(proto:, address:)
          @node_ids_by_address_lock.synchronize do
            @node_ids_by_address[proto][address]
          end
        end

        def node_ids_by_proto(proto:)
          @node_ids_by_address_lock.synchronize do
            @node_ids_by_address[proto].values.uniq
          end
        end

        def nodes
          @nodes.values
        end

        def nodes_by_proto(**kwargs)
          node_ids_by_proto(**kwargs).map { |node_id| _node_by_id_safe(node_id: node_id) }.compact
        end

        def register(registration:, api_client: nil)
          id = registration.local.id

          if @nodes.key?(id)
            @nodes[id].update_registration(registration)
          else
            @nodes[id] = RemoteNode.new(
              api_client: api_client,
              manager: @manager,
              registration: registration
            )
          end

          _sync_node_addresses(updated_node: @nodes[id])

          return @nodes[id]
        end

        def to_json(*args, **kwargs)
          {
            nodes: @nodes,
            node_ids_by_address: node_ids_by_address
          }.to_json(*args, **kwargs)
        end

        private

        def _finalize_node(id:)
          node = node_by_id(id)
          raise("INTERNAL ERROR: Attempted to remove unknown node #{id}") unless node

          node.close

          @node_ids_by_address_lock.synchronize do
            node.node_addresses.to_h.each_pair do |proto, address|
              if @node_ids_by_address[proto][address] == node.id
                @logger.warn("Finalizing #{node.id}: Removing #{proto} route to #{node.node_addresses}")
                @node_ids_by_address[proto].delete(node.node_addresses)
              end
            end
          end

          @logger.debug { "#{node.id} finalized" }
        end

        # Indended for use in node_ids_by_address lookups
        def _node_by_id_safe(node_id:)
          return nil unless node_id

          node = @node_lookup_lock.synchronize { node_by_id(node_id) }
          raise("INTERNAL ERROR: Unknown node ID #{node_id}") unless node

          return node
        end

        def _sync_node_addresses(updated_node:)
          @node_ids_by_address_lock.synchronize do
            updated_node.node_addresses.to_h.each_pair do |proto, address|
              if @node_ids_by_address[proto].key?(address)
                next if @node_ids_by_address[proto][address] == updated_node.id

                @logger.warn("Replacing node #{@node_ids_by_address[proto][address]} with #{updated_node.id} for #{proto} #{address}")
              else
                @logger.info("Storing node #{updated_node.id} for #{proto} #{address}")
              end

              @node_ids_by_address[proto][address] = updated_node.id
            end
          end
        end
      end
    end
  end
end
