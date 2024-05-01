require 'base64'
require 'bindata'
require 'digest'
require 'json'
require 'securerandom'

module TunMesh
  class IPC
    class TunMonitorMetric < BinData::Record
      endian :big

      uint8  :source_node_id_length, value: -> { source_node_id.length }
      string :source_node_id, read_length: :source_node_id_length

      float :latency

      def self.decode(payload)
        self.read(payload)
      end

      def encode
        self.to_binary_s
      end
    end
  end
end
