require 'sysvmq'

module TunMesh
  class IPC
    class Queue
      def initialize(queue_id:, buffer_size: 2048, create: false, mode: 0o0660)
        flags = mode
        flags |= (SysVMQ::IPC_CREAT | SysVMQ::IPC_EXCL) if create == true
        
        # Arg 0: Queue ID: msgget(2) arg 0
        # Arg 1: Internal buffer size: Ruby sysvmq extension
        # Arg 2: flags: msgget(2) arg 1
        @mq = SysVMQ.new(queue_id, buffer_size, flags)

        # Hook in the destructor to clean up, if we created the queue
        ObjectSpace.define_finalizer(self, self.class.finalize(@mq)) if create
      rescue StandardError => exc
        raise(exc.class, "Failed to init queue #{queue_id.to_s(16)}: #{exc}")
      end

      def self.finalize(mq)
        proc do
          mq&.destroy
        end
      end
      
      def close
        @mq.destroy
        @mq = nil
      end

      # Push/pop naming is trying to follow https://ruby-doc.org/core-2.5.1/Queue.html
      def pop(non_block=false)
        if non_block
          return @mq.receive(0, SysVMQ::IPC_NOWAIT)
        else
          return @mq.receive(0)
        end
      end
      
      def push(payload)
        @mq.send(payload)
      end
    end
  end
end
      
