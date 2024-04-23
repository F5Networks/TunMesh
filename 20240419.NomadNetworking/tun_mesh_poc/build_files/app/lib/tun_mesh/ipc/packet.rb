require 'bindata'
require 'digest'
require 'json'

module TunMesh
  class IPC
    class Packet < BinData::Record
      endian :big

      uint16 :data_length, value: -> { data.length }
      string :data, read_length: :data_length
      string :md5, read_length: 16, value: -> { Digest::MD5.digest(data) }

      virtual :data_length_test, assert: -> { data.length == data_length }
      virtual :md5_test, assert: -> { Digest::MD5.digest(data) == md5 }

      def self.decode(payload)
        self.read(payload)
      end

      def self.from_json(payload)
        new(**JSON.load(payload).transform_keys(&:to_sym))
      end

      def encode
        self.to_binary_s
      end

      def to_h
        {
          data: data,
          md5: md5
        }
      end

      def to_json(*args, **kwargs)
        to_h.to_json(*args, **kwargs)
      end
    end
  end
end
