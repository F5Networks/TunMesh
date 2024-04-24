require 'base64'
require 'bindata'
require 'digest'
require 'json'
require 'securerandom'

module TunMesh
  class IPC
    # TODO: This doesn't need to be a bindata, as it's not being sent raw.
    # IPC is via JSON
    # TODO: If IPC over queues is kept that should use bindata for speed
    class Packet < BinData::Record
      class PayloadError < StandardError
      end
      
      VERSION = 0x01
      
      endian :big

      uint8  :version, value: -> { VERSION }
      uint16 :data_length, value: -> { data.length }
      string :data, read_length: :data_length

      string :md5_raw, read_length: 16, value: -> { _calculate_raw_md5 }
      uint64 :internal_stamp

      virtual :version_test, assert: -> { version == VERSION }
      virtual :data_length_test, assert: -> { data.length == data_length }
      virtual :md5_raw_test, assert: -> { _calculate_raw_md5 == md5_raw }

      def self.decode(payload)
        self.read(payload)
      rescue StandardError => exc
        raise(PayloadError, exc.to_s)
      end
      
      def self.from_json(raw)
        payload = JSON.load(raw)
        raise(PayloadError.new("Version mismatch.  Expected #{VERSION}, got got #{payload['version']}")) unless VERSION == payload.fetch('version')
        
        rv = new
        rv.b64_data = payload.fetch('b64_data')
        rv.internal_stamp = payload.fetch('internal_stamp')

        raise(PayloadError.new("Checksum mismatch: Expected #{payload[:md5]}, got #{rv.md5}")) unless rv.md5 == payload.fetch('md5')

        return rv
      rescue StandardError => exc
        raise(PayloadError, "Failed to decode: #{exc.class}: #{exc}")
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

      # For logging/debugging
      def id
        "#{self.class}(#{stamp}-#{md5})"
      end

      def md5
        # TODO: More Rubish way
        md5_raw.bytes.map { |b| sprintf("%02x", b) }.join
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
          version: VERSION,
          b64_data: b64_data,
          md5: md5,
          internal_stamp: internal_stamp.to_i,
        }
      end

      def to_json(*args, **kwargs)
        to_h.to_json(*args, **kwargs)
      end

      private

      def _calculate_raw_md5
        Digest::MD5.digest([
                             data,
                             internal_stamp
                           ].join)
      end
    end
  end
end
