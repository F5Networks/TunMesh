require_relative '../token'

module TunMesh
  module ControlPlane
    class API
      class Auth
        class Session
          # This class behaves like a Auth::Token, and is suitable for passing in it's place
          # The primary purpose of this class is to create Auth::Token esque objects that can be passed from Session
          #  to callers, bypassing outbound auth locking if needed.
          class SplitToken
            attr_reader :id

            def initialize(session:, outbound_auth:)
              raise(ArgumentError, "session is not a Auth::Session, got #{session.class}") unless session.is_a? Auth::Session
              raise(ArgumentError, "outbound_auth is not a Auth::Token, got #{outbound_auth.class}") unless outbound_auth.is_a? Auth::Token

              @id = "#{session.id}.#{outbound_auth.id}"
              @session = session
              @outbound_auth = outbound_auth
            end

            #
            # Use thes specified outbound_auth as outbound_auth generation is synchronized in the session
            #
            def new_http_authorization_header_value(**kwargs)
              @outbound_auth.new_http_authorization_header_value(**kwargs)
            end

            def new_token(**kwargs)
              @outbound_auth.new_token(**kwargs)
            end

            #
            # Use the parent .inbound_auth method so it stays evergreen, as inbound auth is updated on external calls
            #
            def verify(**kwargs)
              @session.inbound_auth.verify(**kwargs)
            end

            def verify_http_authorization_header_value(**kwargs)
              @session.inbound_auth.verify_http_authorization_header_value(**kwargs)
            end
          end
        end
      end
    end
  end
end
