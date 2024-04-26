require 'logger'
require_relative 'remote_node'

module TunMesh
  module ControlPlane
    class Registrations
      class RemoteNodePool
        attr_reader :node_ids_by_address

        def initialize(manager:)
          @logger = Logger.new(STDERR, progname: self.class.to_s)
          @manager = manager
          @nodes = {}

          @node_ids_by_address = {}
          @node_ids_by_address_lock = Mutex.new
        end

        def empty?
          @nodes.empty?
        end
        
        def groom!
          @nodes.delete_if do |node_id, node|
            if node.stale?
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

        def ids
          @nodes.keys
        end

        def node_by_address(address)
          node_id = node_id_by_address(address)
          raise("INTERNAL ERROR: Address lookup for #{address} returned unknown ID #{node_id}") unless node_id
          
          node_by_id(node_id_by_address(address))
        end

        def node_by_id(id)
          @nodes[id]
        end

        def node_id_by_address(address)
          @node_ids_by_address_lock.synchronize do
            @node_ids_by_address[address]
          end
        end

        def nodes
          @nodes.values
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
            if @node_ids_by_address[node.private_address] == node.id
              @logger.warn("Finalizing #{node.id}: Removing route to #{node.private_address}")
              @node_ids_by_address.delete(node.private_address)
            end
          end

          @logger.debug("#{node.id} finalized")
        end

        def _sync_node_addresses(updated_node:)
          @node_ids_by_address_lock.synchronize do
            if @node_ids_by_address.key?(updated_node.private_address)
              return if @node_ids_by_address[updated_node.private_address] == updated_node.id

              @logger.warn("Replacing node #{@node_ids_by_address[updated_node.private_address]} with #{updated_node.id} for #{updated_node.private_address}")
              @nodes[@node_ids_by_address[updated_node.private_address]]&.close
            else
              @logger.info("Storing node #{updated_node.id} for #{updated_node.private_address}")
            end
            
            @node_ids_by_address[updated_node.private_address] = updated_node.id
          end
        end       
      end
    end
  end
end
