require 'bindata'

module TunMesh
  module VPN
    module Packets
      module IP
        class IPv6 < BinData::Record
          ETHERTYPE = 0x86dd
          PROTO     = :ipv6

          endian :big

          bit4  :version, value: 6
          bit6  :traffic_class_ds
          bit2  :traffic_class_ecn
          bit20 :flow_label

          uint16  :payload_length, value: -> { data.length }
          uint8   :next_header
          uint8   :hop_limit
          uint128 :source_address
          uint128 :dest_address

          string :data, read_length: :payload_length

          def self.decode(payload)
            self.read(payload)
          end

          # No port: Layer 3 only
          def dest_str
            _int_to_ip(dest_address)
          end

          def encode
            self.to_binary_s
          end

          # No port: Layer 3 only
          def source_str
            _int_to_ip(source_address)
          end

          private

          def _int_to_ip(ip_int)
            full_str = Array.new(16) { |i| (ip_int >> (i * 8)) & 0xff }.reverse.each_slice(2).to_a.map { |s| sprintf('%02x%02x', *s) }.join(':')
            return full_str.gsub(/:0+/, ':').gsub(/::+/, '::')
          end
        end
      end
    end
  end
end
