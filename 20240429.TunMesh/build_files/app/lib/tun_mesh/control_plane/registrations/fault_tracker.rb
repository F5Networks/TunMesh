module TunMesh
  module ControlPlane
    class Registrations
      class FaultTracker
        class FaultBlocked < StandardError
        end
        
        def initialize(ttl:)
          @tracker = {}
          @tracker_lock = Mutex.new
          
          @ttl = ttl
        end

        def blocked?(id:)
          @tracker_lock.synchronize do
            _groom
            return @tracker.key?(id)
          end
        end
        
        def groom
          @tracker_lock.synchronize { _groom }
        end            
        
        def instrument(id:)
          raise FaultBlocked if blocked?(id: id)

          return yield
        rescue StandardError => exc
          @tracker[id] = Time.now.to_f
          raise exc
        end

        private

        def _groom
          clear_stamp = Time.now.to_f - @ttl
          @tracker.delete_if { |_, last_fault| last_fault < clear_stamp }
        end
      end
    end
  end
end
