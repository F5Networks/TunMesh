require './lib/tun_mesh/concurrent_lock'
require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/api/client'
require './lib/tun_mesh/logger'
require_relative 'errors'
require_relative 'token'
require_relative 'session/split_token'

module TunMesh
  module ControlPlane
    class API
      class Auth
        class Session
          attr_reader :id

          def initialize(api_client:, id:)
            @id = id
            @logger = TunMesh::Logger.new(id: "#{self.class}(#{id})")
            @api_client = api_client
            @outbound_lock = TunMesh::ConcurrentLock.new(id: "#{self.class}(#{id})")
          end

          def auth_wrapper
            @outbound_lock.block do
              begin
                return yield(token)
              rescue TunMesh::ControlPlane::API::Client::RequestException => exc
                if exc.code.to_i >= 400 && exc.code.to_i < 500
                  @logger.warn("Outbound auth operation returned #{exc.code}: Invalidating session #{@outbound_auth&.id}")
                  _invalidate_outbound!(id: @outbound_auth&.id)
                end
                raise exc
              end
            end
          end

          def inbound_auth
            # This is expected to be set by a request from the remote node when they set up the outbound session auth
            # The other end is also expected to groom this and keep our end up to date
            raise(AuthError, 'No inbound auth') unless @inbound_auth
            raise(AuthError, 'Inbound session auth is expired') if _inbound_expired?

            return @inbound_auth
          end

          def inbound_auth=(new_auth)
            raise(ArgumentError, "new_auth is not a Auth::Token, got #{new_auth.class}") unless new_auth.is_a? Auth::Token

            @inbound_auth = new_auth
            @logger.debug("Updated inbound session auth to #{@inbound_auth.id}")
          end

          def outbound_auth
            return @outbound_auth unless _outbound_expired?

            @outbound_lock.synchronize { _init_outbound }
          end

          def token
            return Session::SplitToken.new(session: self, outbound_auth: outbound_auth)
          end

          # Dedicated method for cases where the blocking token can deadlock, namely the auth endpoints
          # For example: Return @outbound_auth directly if this is for a mutual auth response and @outbound_auth exists.
          # This path is to prevent a deadlock where:
          # - R requests a session from G using the session token
          # - G goes to sign the response with its session token, but it is past the refresh threshold
          # - G requests a new session from R using its session token
          # - R goes to sign the response with its session token, but it is locked as the initial request has not yet completed
          # - The nodes are deadlocked until the requests time out
          # This is only a risk on session rotations.
          # Returning @outbound_auth directly relies on the validity_window splay being several times larger than the reregistration window
          #   to cause the sessions to rotate outbound several cycles before they will be rejected inbound.
          def unblocked_token
            # This should only be called in session specific endpoints, after the remote endpoint has set up auth
            unless @outbound_auth
              @logger.error('unblocked_token called with no outbnound auth')
              raise(AuthError, 'Outbound auth token was invalidated or not initialized')
            end

            return Session::SplitToken.new(session: self, outbound_auth: @outbound_auth)
          end

          private

          def _inbound_expired?
            return true unless @inbound_auth

            @inbound_auth&.age.to_i > _inbound_expiration_threshold
          end

          def _outbound_expired?
            return true unless @outbound_auth

            @outbound_auth&.age.to_i > _outbound_expiration_threshold
          end

          def _inbound_expiration_threshold
            @inbound_expiration_threshold ||= (TunMesh::CONFIG.values.process.timing.auth.session_max_age + TunMesh::CONFIG.values.process.timing.auth.validity_window)
          end

          def _init_outbound
            if @outbound_auth && _outbound_expired?
              begin
                @logger.info("Rotating outbound auth: #{@outbound_auth.age}s old")
                # This is locked, but init_session_token needs the session token to self-rotate.
                # Don't pass request_token as that will deadlock.
                @outbound_auth = @api_client.init_session_token(session_auth_token: Session::SplitToken.new(session: self, outbound_auth: @outbound_auth))
                @logger.info("Rotated outbound session auth to #{@outbound_auth.id}")
              rescue StandardError => exc
                @logger.error("Failed to rotate outbound auth: #{exc.class}: #{exc}")
                @logger.debug(exc.backtrace)
              end
            end

            return @outbound_auth if @outbound_auth

            begin
              @outbound_auth = @api_client.init_session_token(session_auth_token: nil)
              @logger.info("Initialized outbound session auth to #{@outbound_auth.id}")
            rescue StandardError => exc
              @logger.error("Failed to initialize outbound auth: #{exc.class}: #{exc}")
              @logger.debug(exc.backtrace)
              raise(AuthError, "Failed to initialize outbound auth: #{exc.class}: #{exc}")
            end

            return @outbound_auth
          end

          def _invalidate_outbound!(id:)
            @outbound_lock.synchronize do
              return unless @outbound_auth

              if id.nil?
                @logger.debug('Ignoring invalidate_outbound! request for nil ID')
                return
              end

              if id == @outbound_auth.id
                @logger.debug("Invalidating outbound_auth #{id}")
                @outbound_auth = nil
              else
                @logger.debug("Ignoring invalidate_outbound! request for #{id}, current outbound ID #{@outbound_auth&.id}")
              end
            end
          end

          def _outbound_expiration_threshold
            @outbound_expiration_threshold ||= (TunMesh::CONFIG.values.process.timing.auth.session_max_age - TunMesh::CONFIG.values.process.timing.auth.validity_window)
          end
        end
      end
    end
  end
end
