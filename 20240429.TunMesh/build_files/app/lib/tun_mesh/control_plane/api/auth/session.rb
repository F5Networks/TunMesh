require 'logger'
require './lib/tun_mesh/concurrent_lock'
require './lib/tun_mesh/config'
require './lib/tun_mesh/control_plane/api/client'
require_relative 'errors'
require_relative 'token'

module TunMesh
  module ControlPlane
    class API
      class Auth
        class Session
          def initialize(api_client:)
            @logger = Logger.new($stderr, progname: self.class.to_s)
            @api_client = api_client
            @outbound_lock = TunMesh::ConcurrentLock.new
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

          def invalidate_outbound!(id:)
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

          def outbound_auth
            @outbound_lock.synchronize { _outbound_auth }
          end

          def outbound_auth_wrapper
            @outbound_lock.block do
              return yield(self)
            rescue TunMesh::ControlPlane::API::Client::RequestException => exc
              if exc.code.to_i >= 400 && exc.code.to_i < 500
                @logger.warn("Outbound auth operation returned #{exc.code}: Invalidating session #{@outbound_auth&.id}")
                invalidate_outbound!(id: @outbound_auth&.id)
              end
              raise exc
            end
          end

          #
          # Shims to behave like Auth::Token
          #
          def new_http_authorization_header_value(**kwargs)
            outbound_auth.new_http_authorization_header_value(**kwargs)
          end

          def new_token(**kwargs)
            outbound_auth.new_token(**kwargs)
          end

          def verify(**kwargs)
            inbound_auth.verify(**kwargs)
          end

          def verify_http_authorization_header_value(**kwargs)
            inbound_auth.verify_http_authorization_header_value(**kwargs)
          end

          private

          def _inbound_expired?
            @inbound_auth&.age.to_i > _inbound_expiration_threshold
          end

          def _outbound_expired?
            @outbound_auth&.age.to_i > _outbound_expiration_threshold
          end

          def _inbound_expiration_threshold
            @inbound_expiration_threshold ||= (TunMesh::CONFIG.values.process.timing.auth.session_max_age + TunMesh::CONFIG.values.process.timing.auth.validity_window)
          end

          def _outbound_auth
            if @outbound_auth && _outbound_expired?
              begin
                @logger.info("Rotating outbound auth: #{@outbound_auth.age}s old")
                @outbound_auth ||= @api_client.init_session_token(outbound_auth: @outbound_auth)
                @logger.info("Rotated outbound session auth to #{@outbound_auth.id}")
              rescue StandardError => exc
                @logger.error("Failed to rotate outbound auth: #{exc.class}: #{exc}")
                @logger.debug(exc.backtrace)
              end
            end

            return @outbound_auth if @outbound_auth

            begin
              @outbound_auth = @api_client.init_session_token(outbound_auth: nil)
              @logger.info("Initialized outbound session auth to #{@outbound_auth.id}")
            rescue StandardError => exc
              @logger.error("Failed to initialize outbound auth: #{exc.class}: #{exc}")
              @logger.debug(exc.backtrace)
              raise(AuthError, "Failed to initialize outbound auth: #{exc.class}: #{exc}")
            end

            return @outbound_auth
          end

          def _outbound_expiration_threshold
            @outbound_expiration_threshold ||= (TunMesh::CONFIG.values.process.timing.auth.session_max_age - TunMesh::CONFIG.values.process.timing.auth.validity_window)
          end
        end
      end
    end
  end
end
