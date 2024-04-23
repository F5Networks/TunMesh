require 'base64'
require 'bindata'
require 'digest'
require 'json'
require 'securerandom'

module TunMesh
  class IPC
    class Packet < BinData::Record
      VERSION = 0x01
      
      endian :big

      uint8  :version, value: -> { VERSION }
      uint16 :data_length, value: -> { data.length }
      string :data, read_length: :data_length
      string :md5_raw, read_length: 16, value: -> { Digest::MD5.digest(data) }
      uint64 :internal_stamp

      uint8  :id_internal_length, value: -> { id_internal.length }
      string :id_internal

      virtual :version_test, assert: -> { version == VERSION }
      virtual :data_length_test, assert: -> { data.length == data_length }
      virtual :md5_raw_test, assert: -> { Digest::MD5.digest(data) == md5_raw }
      virtual :id_internal_length_test, assert: -> { id_internal.length == id_internal_length }

      def self.decode(payload)
        self.read(payload)
      end
      
      def self.from_json(payload)
        rv = new
        # Not using new(**args) as the json encoding needs to run through decoding setters
        JSON.load(payload).each_pair do |key, value|
          rv.send("#{key}=", value)
        end

        return rv
      end

      def b64_data
        return Base64.encode64(data)
      end

      def b64_data=(d64)
        self.data = Base64.decode64(d64)
      end
      
      def encode
        self.to_binary_s
      end

      def id
        # ID is only set when used, intended for debug/trace level logging
        # If nothing is using the IDs, don't bother generating/sending them
        # TODO: Is SecureRandom the right lib here?  This might make a *lot* of IDs.
        # TODO: Better ID.  Something that hints where/when it came from
        self.id_internal = SecureRandom.uuid if self.id_internal.empty?

        # TODO
        return "Packet(#{id_internal})"
      end

      def md5
        # TODO: More Rubish way
        md5_raw.bytes.map { |b| sprintf("%02x", b) }.join
      end

      def md5=(hex_md5)
        # TODO: More Rubish way
        md5 = hex_md5.chars.each_slice(2).to_a.map(&:join).map { |v| v.to_i(16).chr }.join
      end

      def stamp
        # TODO: better way
        internal_stamp.to_f / (2**30)
      end

      def stamp=(new_stamp)
        self.internal_stamp = (new_stamp * 2**30).to_i
      end

      def to_h
        {
          b64_data: b64_data,
          md5: md5,
          internal_stamp: internal_stamp.to_i,
          id_internal: id_internal
        }
      end

      def to_json(*args, **kwargs)
        to_h.to_json(*args, **kwargs)
      end
    end
  end
end
