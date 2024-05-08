module TunMesh
  # This class implements a lock which can both be exclusively and concurrently locked
  # Exclusive locks behave like a normal Mutex
  # Concurrent locks will block exclusive locks
  class ConcurrentLock
    def initialize
      @exclusive_lock = Mutex.new
      @concurrent_locks = {}
    end

    def active_blocks
      @concurrent_locks.length
    end

    # Block will prevent a lock, but not other blocks
    # Can be called recursively
    def block
      # Support nested blocking
      return yield if @concurrent_locks[Thread.current]&.owned?

      concurrent_lock = Mutex.new
      concurrent_lock.synchronize do
        @exclusive_lock.synchronize do
          @concurrent_locks[Thread.current] = concurrent_lock
        end

        yield
      end
    ensure
      @concurrent_locks.delete(Thread.current)
    end

    def block_held?
      @concurrent_locks[Thread.current]&.owned?
    end

    def lock_held?
      @exclusive_lock.owned?
    end

    # Synchronize behaves like normal Mutex.synchronize
    # Can be called when a block is held
    def synchronize
      self_concurrent_lock = @concurrent_locks.delete(Thread.current)
      self_concurrent_lock&.unlock
      rv = nil

      @exclusive_lock.synchronize do
        until @concurrent_locks.empty?
          @concurrent_locks.delete_if do |_, lock|
            lock.synchronize do
              true
            end
          end
        end

        rv = yield
      end

      return rv
    ensure
      if self_concurrent_lock
        self_concurrent_lock.lock
        @concurrent_locks[Thread.current] = self_concurrent_lock
      end
    end

    # try_lock is not available due to the block pattern and supporting locking within blocking.
  end
end
