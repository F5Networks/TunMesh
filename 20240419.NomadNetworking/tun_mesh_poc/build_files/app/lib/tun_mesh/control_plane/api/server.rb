require 'sinatra/base'
require 'prometheus/middleware/exporter'
require './lib/tun_mesh/config'
require_relative 'server_routes/auth'
require_relative 'server_routes/control'
require_relative 'server_routes/health'

module TunMesh
  module ControlPlane
    class API
      class Server < Sinatra::Base
        ROUTES = [
          ServerRoutes::Auth,
          ServerRoutes::Control,
          ServerRoutes::Health
        ]

        ROUTES.each { |route| register route }

        use(Prometheus::Middleware::Exporter) if TunMesh::CONFIG.values.monitoring.method == 'prometheus'
        
        not_found do
          status 404
          body "Not Found"
        end
        
        def self.run!(**kwargs)
          ROUTES.each { |route| _set_route_args(kwargs: kwargs, route: route) }

          # https://puma.io/puma/
          puma_bind = [
            "ssl://0.0.0.0:", TunMesh::CONFIG.values.control_api.listen_port,
            "?key=", TunMesh::CONFIG.values.control_api.ssl.key_file_path,
            "&cert=", TunMesh::CONFIG.values.control_api.ssl.cert_file_path
          ]
          Sinatra::Base.set(:bind, puma_bind.join)

          super
        end

        def self._set_route_args(kwargs:, route:)
          route::REQUIRED_ARGS.each do |arg_name|
            raise(ArgumentError, "Missing required argument #{arg_name}") unless kwargs.key? arg_name
            # https://sinatrarb.com/configuration.html
            # https://stackoverflow.com/questions/9657202/pass-arguments-to-new-sinatra-app/9657478#9657478
            route.set(arg_name, kwargs.fetch(arg_name))
          end
        end
      end
    end
  end
end

          
        
