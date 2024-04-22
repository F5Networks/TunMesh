require 'httparty'
require 'logger'
require_relative 'structs/registration'

module TunMesh
  module ControlPlane
    class APIClient
      class RequestException < RuntimeError
        attr_reader :code
        
        def initialize(message, code)
          @code = code
          super(message)
        end
      end
      
      def initialize(remote_url:)
        @logger = Logger.new(STDERR, progname: "#{self.class}(#{remote_url})")
        @remote_url = remote_url
      end

      def register(payload:)
        raise(ArgumentError, "Payload must be a TunMesh::ControlPlane::Structs::Registration, got #{payload.class}") unless payload.is_a? TunMesh::ControlPlane::Structs::Registration
        return _post(path: 'tunmesh/control/v0/registrations/register',
                     payload: payload)
      end

      private

      def _post(path:, payload:)
        # TODO: URL builder lib
        url = "#{@remote_url}/#{path}"
        @logger.debug { "Performing HTTP POST to #{url}" }
        
        # TODO: Connection reuse
        resp = HTTParty.post(url, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })
        return nil if resp.code == 204
        raise(RequestException.new("HTTP POST to #{url} returned #{resp.code}", resp.code)) if resp.code < 200 || resp.code >= 300

        if resp.code == 200
          raise(RequestException.new("HTTP POST to #{url} returned content type #{resp.headers['content-type']}", resp.code)) if resp.headers['content-type'] != 'application/json'
          return resp.body
        end

        raise(RequestException.new("HTTP POST to #{url} returned unexpected content/code #{resp.headers['content-type']} / #{resp.code}", resp.code))
      end
    end
  end
end
