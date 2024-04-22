require 'yaml'

module TunMesh
  # App config
  # TODO: MVP, over simple
  class Config
    def initialize(path: ENV.fetch('TUNMESH_CONFIG_PATH', '/etc/tunmesh/config.yaml'))
      @config = YAML.safe_load(File.read(path))
    end

    def advertise_url
      @config.fetch('control').fetch('advertise_url')
    end

    def bootstrap_node_urls
      @config.fetch('discovery').fetch('bootstrap_node_urls')
    end

    def control_listen_port
      @config.fetch('control').fetch('listen_port', 4567)
    end

    def private_address_cidr
      @config.fetch('internal').fetch('private_address_cidr')
    end
  end

  CONFIG = Config.new.freeze
end
