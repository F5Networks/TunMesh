require 'pathname'
require 'logger'
require 'securerandom'
require 'yaml'

require_relative './config/top'
require_relative './config/errors'

module TunMesh
  # App config
  class Config
    attr_reader :node_id

    def initialize
      @logger = Logger.new($stderr, progname: self.class.to_s)
      @node_id = SecureRandom.uuid
    end

    def config_path
      self.config_path = ENV.fetch('TUNMESH_CONFIG_PATH', '/etc/tunmesh/config.yaml') unless @config_path
      return @config_path
    end

    def config_path=(path)
      path_obj = Pathname.new(path) # Used in the file type for relative pathing
      raise("#{path} not a file") unless path_obj.file?

      @config_path = path_obj
    end

    def example_config
      lines = [
        "# Example tun_mesh config, generated #{Time.now}",
        '---'
      ]
      lines += Config::Top.new.example_config_lines
      return lines.join("\n")
    end

    def parse_config!
      @logger.info("Parsing config file #{config_path}")
      yaml_parsed_contents = YAML.safe_load(config_path.read)

      raise(Config::Errors::MissingKeyError.new('Missing top level tun_mesh key', 'tun_mesh')) unless yaml_parsed_contents.key?('tun_mesh')

      # Pass self through at a root of tree so parsers can cross-reference
      @parsed_top_group = Config::Top.new
      @parsed_top_group.load_config_value(value: yaml_parsed_contents['tun_mesh'], config_obj: self)
    rescue Config::Errors::ParseError => exc
      faulted_key = exc.key
      faulted_key ||= '[Unknown]'

      warn("Failed to parse config file #{config_path}")
      warn("#{exc.class} at key #{faulted_key}: #{exc}")
      warn('')

      raise exc
    rescue StandardError => exc
      warn("Failed to parse config file #{config_path}")
      warn("#{exc.class}: #{exc}")
      warn('')
      raise exc
    end

    # Test helper
    def stub!
      @parsed_top_group = Config::Top.new
    end

    def values
      parse_config! unless @parsed_top_group
      @parsed_top_group.value
    end
  end

  CONFIG = Config.new
end
