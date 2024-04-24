require 'sinatra/base'
require './lib/tun_mesh/config'
require_relative 'routes/control'

module TunMesh
  module ControlPlane
    module API
      class Server < Sinatra::Base
        register Routes::Control
        
        def self.run!(**args)
          _set_route_args(args: args, route: Routes::Control)

          Sinatra::Base.set(:bind, '0.0.0.0')
          Sinatra::Base.set(:port, TunMesh::CONFIG.control_listen_port)

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

          
        
