require 'pathname'
require 'securerandom'
require 'yaml'

require_relative './config/top'
require_relative './config/errors'

module TunMesh
  # App config
  class Config
    attr_reader :config_path, :node_id
    
    def initialize
      @top_group = Config::Top.new
      @node_id = SecureRandom.uuid
    end

    def example_config
      lines = [
        "# Example tun_mesh config, generated #{Time.now}",
        '---',
      ]
      lines += @top_group.example_config_lines
      return lines.join("\n")
    end
    
    def parse_file(path)
      @config_path = Pathname.new(path) # Used in the file type for relative pathing
      yaml_parsed_contents = YAML.safe_load(File.read(path))
      
      raise(Config::Errors::MissingKeyError.new("Missing top level tun_mesh key", 'tun_mesh')) unless yaml_parsed_contents.key?('tun_mesh')

      # Pass self through at a root of tree so parsers can cross-reference
      @top_group.load_config_value(value: yaml_parsed_contents['tun_mesh'], config_obj: self)
      @parsed = true
    rescue Config::Errors::ParseError => exc
      faulted_key = exc.key
      faulted_key ||= '[Unknown]'
      
      warn("Failed to parse config file #{path}")
      warn("#{exc.class} at key #{faulted_key}: #{exc}")
      warn('')
      
      raise exc
    rescue StandardError => exc
      warn("Failed to parse config file #{path}")
      warn("#{exc.class}: #{exc}")
      warn('')
      raise exc
    end

    def values
      parse_file(ENV.fetch('TUNMESH_CONFIG_PATH', '/etc/tunmesh/config.yaml')) unless @parsed
      @top_group.value
    end
  end

  CONFIG = Config.new
end
