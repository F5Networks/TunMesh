require './spec/helpers/spec_helper'
require './lib/tun_mesh/concurrent_lock'

describe TunMesh::ConcurrentLock do
  subject { described_class.new }

  let(:test_thread_count) { 1000 }

  describe 'Return value passthrough' do
    it 'passes block values through block' do
      test_value = SecureRandom.hex
      expect(subject.block { test_value }).to eq test_value
    end

    it 'passes block values through synchronize' do
      test_value = SecureRandom.hex
      expect(subject.synchronize { test_value }).to eq test_value
    end
  end

  describe 'Locking & Blocking' do
    it 'only allows one exclusive lock at a time' do
      example_lock = Mutex.new
      lock_bypasses = 0
      threads = Array.new(test_thread_count) do
        Thread.new do
          # Sleep a random but small amount so these don't all just hit the lock in order
          sleep(rand(0.0001..0.01))
          subject.synchronize do
            if example_lock.try_lock
              example_lock.unlock
            else
              lock_bypasses += 1
            end

            # Sleep a random but small amount in the lock to cause some contention
            sleep(rand(0.0001..0.01))
          end
        end
      end

      threads.each(&:join)
      expect(lock_bypasses).to eq 0
    end

    it 'allows multiple concurrent blocks on the exclusive lock' do
      block_release = Mutex.new
      block_release.lock
      active_threads = 0

      threads = Array.new(test_thread_count) do
        active_threads += 1
        Thread.new do
          subject.block do
            block_release.synchronize { nil }
            # These should all run in parallel.
            sleep(1)
            active_threads -= 1
          end
        end
      end

      expect(active_threads).to eq test_thread_count
      sleep(0.01) while subject.active_blocks < test_thread_count

      release_time = Time.now.to_f
      block_release.unlock
      subject.synchronize do
        lock_time = Time.now.to_f
        expect(active_threads).to eq 0
        expect(threads.select(&:alive?)).to be_empty
        expect(subject.active_blocks).to eq 0
        expect(lock_time - release_time).to be > 1.0
      end
    end

    it 'Does not allow concurrent blocks when the exclusive lock is active' do
      active_threads = 0
      start_times = {}
      threads = []
      exclusive_end_time = nil
      subject.synchronize do
        threads = Array.new(test_thread_count) do |i|
          active_threads += 1
          Thread.new do
            subject.block do
              start_times[i] = Time.now.to_f
              # These should all run in parallel.
              sleep(0.5)
              active_threads -= 1
            end
          end
        end

        expect(active_threads).to eq test_thread_count

        sleep(1)

        expect(active_threads).to eq test_thread_count
        expect(subject.active_blocks).to eq 0

        exclusive_end_time = Time.now.to_f
      end

      expect(active_threads).to eq test_thread_count
      threads.each(&:join)
      expect(active_threads).to eq 0

      expect(start_times.transform_values { |st| st - exclusive_end_time }.reject { |_, v| v > 0 }).to be_empty
    end

    it 'supports upgrading to an exclusive lock from within a block' do
      example_lock = Mutex.new
      lock_bypasses = 0
      lock_acquisitions = 0

      block_release = Mutex.new
      block_release.lock
      active_threads = 0

      threads = Array.new(test_thread_count) do
        active_threads += 1
        Thread.new do
          subject.block do
            block_release.synchronize { nil }

            # Sleep a random but small amount so these don't all just hit the lock in order
            sleep(rand(0.0001..0.01))
            subject.synchronize do
              if example_lock.try_lock
                example_lock.unlock
                lock_acquisitions += 1
              else
                lock_bypasses += 1
              end

              # Sleep a random but small amount in the lock to cause some contention
              sleep(rand(0.0001..0.01))
            end

            active_threads -= 1
          end
        end
      end

      expect(active_threads).to eq test_thread_count
      sleep(0.01) while subject.active_blocks < test_thread_count

      expect(active_threads).to eq test_thread_count
      expect(subject.active_blocks).to eq test_thread_count

      block_release.unlock

      threads.each(&:join)

      expect(lock_bypasses).to eq 0
      expect(lock_acquisitions).to eq test_thread_count
    end

    it 'supports recursive blocking' do
      test_value = SecureRandom.hex
      block_level_values = Hash.new do |h, k|
        subject.block do
          if k == 0
            test_value
          else
            h[k] = h[k - 1]
          end
        end
      end

      expect(block_level_values[100]).to eq test_value
    end
  end
end
