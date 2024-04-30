require 'bindata'

module TunMesh
  module VPN
    module Packets
      module IP
        class IPv4 < BinData::Record
          ETHERTYPE = 0x0800
          PROTO     = :ipv4

          endian :big

          bit4 :version, value: 4
          bit4 :ihl, value: -> { (options.length / 4) + 5 }
          bit6 :dscp
          bit2 :ecn
          uint16 :total_length, value: -> { options.length + data.length + 20 }
          uint16 :identification
          bit3 :flags
          bit13 :fragment_offset
          uint8 :ttl
          uint8 :protocol

          # NOTE: This implementation is a parser only, and does not have code to
          #    generate the checksum when building a packet.
          # Building IPv4 packets from scratch is not currently supported.
          uint16 :header_checksum
          uint32 :source_address
          uint32 :dest_address
          string :options, read_length: :options_length_in_bytes
          string :data, read_length: :data_length_in_bytes

          virtual :version_test, assert: -> { version == 4 }
          virtual :options_length_test, assert: -> { (options.length % 4) == 0 }

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

          def data_length_in_bytes
            total_length - header_length_in_bytes
          end

          def header_length_in_bytes
            ihl * 4
          end

          def options_length_in_bytes
            header_length_in_bytes - 20
          end

          # No port: Layer 3 only
          def source_str
            _int_to_ip(source_address)
          end

          private

          def _int_to_ip(ip_int)
            Array.new(4) { |i| (ip_int >> (i * 8)) & 0xff }.reverse.join('.')
          end
        end
      end
    end
  end
end
