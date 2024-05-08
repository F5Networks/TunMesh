require 'base64'
require 'bindata'
require 'digest'
require 'json'
require 'securerandom'

module TunMesh
  class IPC
    class Packet < BinData::Record
      class PayloadError < StandardError
      end

      class TunHeader < BinData::Record
        endian :big

        # https://github.com/amoghe/rb_tuntap/tree/master
        uint16 :flags
        uint16 :ethertype
      end

      VERSION = 0x03

      endian :big

      uint8  :version, value: -> { VERSION }

      uint16 :ethertype
      uint16 :data_length, value: -> { data.length }
      string :data, read_length: :data_length

      string :md5_raw, read_length: 16, value: -> { _calculate_raw_md5 }
      uint64 :internal_stamp

      uint8  :source_node_id_length, value: -> { source_node_id.length }
      string :source_node_id, read_length: :source_node_id_length

      virtual :version_test, assert: -> { version == VERSION }
      virtual :data_length_test, assert: -> { data.length == data_length }
      virtual :md5_raw_test, assert: -> { _calculate_raw_md5 == md5_raw }

      def self.decode(payload)
        self.read(payload)
      rescue StandardError => exc
        raise(PayloadError, exc.to_s)
      end

      def self.from_json(raw)
        payload = JSON.parse(raw)
        raise(PayloadError.new("Version mismatch.  Expected #{VERSION}, got got #{payload['version']}")) unless VERSION == payload.fetch('version')

        rv = new
        rv.ethertype = payload.fetch('ethertype')
        rv.b64_data = payload.fetch('b64_data')
        rv.internal_stamp = payload.fetch('internal_stamp')
        rv.source_node_id = payload.fetch('source_node_id')

        raise(PayloadError.new("Checksum mismatch: Expected #{payload[:md5]}, got #{rv.md5}")) unless rv.md5 == payload.fetch('md5')

        return rv
      rescue StandardError => exc
        raise(PayloadError, "Failed to decode: #{exc.class}: #{exc}", exc.backtrace)
      end

      # Loads with from a rb_tuntap response with pkt_info enabled
      def self.from_tun(raw:, rx_stamp:)
        header = TunHeader.read(raw[0..3])
        @flags = header.flags
        packet = new(data: raw[4..-1], ethertype: header.ethertype, source_node_id: TunMesh::CONFIG.node_id)
        packet.stamp = rx_stamp
        return packet
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

      def flags
        # Only set in from_tun(), no current use in receiver so not in main packet
        @flags
      end

      # For logging/debugging
      def id
        rv = "#{self.class}(#{source_node_id}-#{stamp}-#{format('0x%04x', ethertype)}-#{md5})"
        rv += "(Flags: #{format('0x%04x', flags)})" unless flags.nil?
        return rv
      end

      def md5
        _calculate_raw_md5 if md5_raw.empty?
        md5_raw.bytes.map { |b| format('%02x', b) }.join
      end

      def stamp
        internal_stamp.to_f / (2**30)
      end

      def stamp=(new_stamp)
        self.internal_stamp = (new_stamp * 2**30).to_i
      end

      def to_h
        {
          version: VERSION,
          ethertype: ethertype.to_i,
          b64_data: b64_data,
          md5: md5,
          internal_stamp: internal_stamp.to_i,
          source_node_id: source_node_id
        }
      end

      def to_json(*args, **kwargs)
        to_h.to_json(*args, **kwargs)
      end

      def to_tun
        header = TunHeader.new(flags: 0x00, ethertype: ethertype)
        return header.to_binary_s + data
      end

      private

      def _calculate_raw_md5
        Digest::MD5.digest([
          data,
          ethertype,
          internal_stamp,
          source_node_id
        ].join)
      end
    end
  end
end
