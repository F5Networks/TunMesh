require_relative 'api/auth'
require_relative 'api/client'
require_relative 'api/server'

module TunMesh
  module ControlPlane
    class API
      attr_reader :auth

      def initialize(manager:)
        @auth = Auth.new(api: self)
        @manager = manager
      end

      def client_for_node_id(id:)
        @manager.registrations.node_by_id(id)&.api_client
      end

      def new_client(**kwargs)
        return Client.new(**{ api_auth: @auth }.merge(kwargs))
      end

      def run!(&block)
        API::Server.run!(
          api_auth: @auth,
          manager: @manager,
          &block
        )
      end
    end
  end
end
