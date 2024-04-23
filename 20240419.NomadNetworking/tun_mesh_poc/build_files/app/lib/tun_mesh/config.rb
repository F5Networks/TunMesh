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

    # TODO: internal: bad namespace
    def private_address_cidr
      @config.fetch('internal').fetch('private_address_cidr')
    end

    def tun_device_name
      @config.fetch('internal').fetch('tun_device_name')
    end

    # tunnel inbound
    def tun_read_pipe_path
      @config.fetch('ipc').fetch('read_pipe_path')
    end

    # Tunnel outbound
    def tun_write_pipe_path
      @config.fetch('ipc').fetch('write_pipe_path')
    end
  end

  CONFIG = Config.new.freeze
end
