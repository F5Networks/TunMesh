require './lib/tun_mesh/config'
require_relative 'queue'

module TunMesh
  class IPC
    class QueueManager
      QUEUE_SUB_IDS = {
        # tun queues are currently proper interprocess
        # The tun_handler program needs high privilege to cfreate a network device and update routes
        # As such it performs only the minimum abount of processing due to the high privilege level needed.
        # As of 20240423 this app does not fork to drop privileges, because MVP.
        tun_read: 0x00, # tun -> app
        tun_write: 0x01 # app -> tun

        # 0x02 - 0x0f available
      }.freeze

      QUEUE_FULL_IDS = QUEUE_SUB_IDS.transform_values { |sub_id| TunMesh::CONFIG.ipc_queue_id | sub_id }.freeze

      QUEUE_FULL_IDS.each_key do |queue_name|
        define_method(queue_name) { @queues[queue_name] }
      end

      def initialize(control:)
        raise("CONFIG ERROR: The last 4 bits of the IPC Queue ID are reserved") if (TunMesh::CONFIG.ipc_queue_id & 0x0f) != 0
        @control = control

        # Storing the queues in a hash because ... it's easy.
        @queues = Hash.new do |h,k|
          h[k] = Queue.new(queue_id: QUEUE_FULL_IDS.fetch(k), buffer_size: 2048, create: @control, mode: 0o660)
        end
      end
    end
  end
end
