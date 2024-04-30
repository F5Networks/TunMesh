module TunMesh
  module ControlPlane
    class Monitoring
      # Null class for when monitoring is disabled
      class NullOutputs
        def add_gauge(**)
          # No-op
        end

        def increment_gauge(**)
          # No-op
        end

        def set_gauge(**)
          # No-op
        end
      end
    end
  end
end
