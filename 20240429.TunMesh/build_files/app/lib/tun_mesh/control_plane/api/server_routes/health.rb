require 'sinatra/extension'
require 'sinatra/json'

module TunMesh
  module ControlPlane
    class API
      module ServerRoutes
        module Health
          extend Sinatra::Extension
          
          # Args are passed in via Sinatra .set in TunMesh::ControlPlane::API::Server.run!
          # This const defines the args this route needs.
          REQUIRED_ARGS = %i[manager].freeze

          get '/health' do
            if settings.manager.healthy?
                status 200
            else
              status 503
            end

            json settings.manager.health
          end
        end
      end
    end
  end
end
