require 'logger'
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
        tun_read: 0x00,     # Packets: tun -> app
        tun_write: 0x01,    # Packets: app -> tun
        tun_heartbeat: 0x02 # heartbeat stamps

        # 0x03 - 0x0f available
      }.freeze

      QUEUE_SUB_IDS.each_key do |queue_name|
        define_method(queue_name) { @queues[queue_name] }
      end

      attr_reader :queue_key

      def initialize(control: false, queue_key: nil)
        raise(ArgumentError, "Control and queue_key are exclusive") if control && queue_key
        raise(ArgumentError, "queue_key must be specified when not in control") if !control && !queue_key
        @control = control

        if queue_key
          raise("CONFIG ERROR: The last 4 bits of the IPC Queue ID are reserved") if (queue_key & 0x0f) != 0
          @queue_key = queue_key
        end

        logger = Logger.new(STDERR, progname: self.class.to_s)

        retries = 0
        begin
          @queue_key = (rand((TunMesh::CONFIG.values.process.ipc.group.key_range_min)..(TunMesh::CONFIG.values.process.ipc.group.key_range_max)) & 0xfffffff0) if @control
          _init_queues
        rescue StandardError => exc
          logger.info("Failed to init with queue_key #{@queue_key.to_s(16)}: Attempt #{retries}: #{exc.class}: #{exc}") if @control

          raise exc unless @control
          raise exc if retries > TunMesh::CONFIG.values.process.ipc.group.max_init_attempts

          retries += 1
          retry
        end

        logger.debug("Successfully initialized with queue_key #{@queue_key.to_s(16)}")
      end

      def close
        @queues.values.each(&:close)
      end

      private

      def _init_queues
        # Storing the queues in a hash because ... it's easy.
        @queues = QUEUE_SUB_IDS.transform_values do |sub_id|
          Queue.new(queue_id: (queue_key | sub_id), buffer_size: 2048, create: @control)
        end
      end
    end
  end
end
