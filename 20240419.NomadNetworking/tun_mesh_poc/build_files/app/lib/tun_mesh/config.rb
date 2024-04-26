require 'securerandom'
require 'yaml'

module TunMesh
  # App config
  # TODO: MVP, over simple
  class Config
    attr_reader :node_id
    
    def initialize(path: ENV.fetch('TUNMESH_CONFIG_PATH', '/etc/tunmesh/config.yaml'))
      @config = YAML.safe_load(File.read(path))
      @node_id = SecureRandom.uuid
    end

    def advertise_url
      @config.fetch('control').fetch('advertise_url')
    end

    def bootstrap_node_urls
      @config.fetch('discovery').fetch('bootstrap_node_urls')
    end

    # TODO: API auth secret
    def control_auth_secret
      @config.fetch('control').fetch('auth').fetch('secret')
    end

    def control_listen_port
      @config.fetch('control').fetch('listen_port', 4567)
    end

    def control_ssl_cert_file_path
      @config.fetch('control').fetch('ssl').fetch('cert_file_path')
    end

    def control_ssl_key_file_path
      @config.fetch('control').fetch('ssl').fetch('key_file_path')
    end
    
    # TODO: internal: bad namespace
    def private_address_cidr
      @config.fetch('internal').fetch('private_address_cidr')
    end

    def tun_device_name
      @config.fetch('internal').fetch('tun_device_name', 'tun1')
    end

    # TODO: Make automatic
    def ipc_queue_id
      @config.fetch('ipc', {}).fetch('queue_id', 0x544e4d00)
    end
  end

  CONFIG = Config.new.freeze
end
