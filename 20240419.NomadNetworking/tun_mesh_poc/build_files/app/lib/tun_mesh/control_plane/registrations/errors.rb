module TunMesh
  module ControlPlane
    class Registrations
      class RegistrationFailed < RuntimeError
      end

      class RegistrationFromSelf < RuntimeError
      end
    end
  end
end
