require 'sinatra/base'
require './lib/tun_mesh/config'
require_relative 'routes/control'
require_relative 'routes/health'

module TunMesh
  module ControlPlane
    module API
      class Server < Sinatra::Base
        register Routes::Control
        register Routes::Health

        not_found do
          status 404
          body "Not Found"
        end
        
        def self.run!(**args)
          _set_route_args(args: args, route: Routes::Control)

          # https://puma.io/puma/
          puma_bind = [
            "ssl://0.0.0.0:", TunMesh::CONFIG.control_listen_port,
            "?key=", TunMesh::CONFIG.control_ssl_key_file_path,
            "&cert=", TunMesh::CONFIG.control_ssl_cert_file_path
          ]
          Sinatra::Base.set(:bind, puma_bind.join)

          super
        end

        def self._set_route_args(args:, route:)
          route::REQUIRED_ARGS.each do |arg_name|
            raise(ArgumentError, "Missing required argument #{arg_name}") unless args.key? arg_name
            # https://sinatrarb.com/configuration.html
            # https://stackoverflow.com/questions/9657202/pass-arguments-to-new-sinatra-app/9657478#9657478
            route.set(arg_name, args.fetch(arg_name))
          end
        end
      end
    end
  end
end

          
        
