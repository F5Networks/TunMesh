require 'ipaddr'
require_relative 'base'


module TunMesh
  module ControlPlane
    module Structs
      # Struct representing a IP Address
      # Bespoke as I can't find a working gem to do this (!!!)
      # IPAddr: Masks the host bits: https://github.com/ruby/ipaddr/issues/67
      # NetAddr::IPv4Net also masks (Net)
      # NetAddr::IPv4 doesn't do CIDRs
      # NetAddr::CIDR appears to have been removed in V2
      class NetAddress < Base
        attr_reader :address

        FIELDS = {
          cidr: {
            type: String
          },
        }

        def self.parse_cidr(cidr)
          return new(cidr: cidr)
        end

        def address
          _parse_cidr unless @address
          return @address
        end

        def include?(other)
          _network_address_obj.include?(other)
        end

        def ipv4?
          _network_address_obj.ipv4?
        end

        def ipv6?
          _network_address_obj.ipv6?
        end

        def netmask
          @netmask ||= IPAddr.new(_network_address_obj.netmask.to_s).to_s
        end

        def network_address
          _network_address_obj.to_s
        end

        # other_ helpers expected to be run against address setings from config network CIDRs
        # other_broadcast is because the broadcast address is dependent on the network address, so comparing an address as an argument is logical
        def other_broadcast?(other_address)
          other_address_obj = NetAddress.parse_cidr("#{other_address}/32")
          other_address_obj.validate_proto(proto)
          return false if other_address_obj.proto == :ipv6 # https://docs.oracle.com/cd/E19455-01/806-0916/6ja8539be/index.html

          return true if other_address_obj.to_i == 0xffffffff # 255.255.255.255 Ref: rfc5735
          return false unless _network_address_obj.include?(other_address_obj.address)

          # Take the network address as an integer, and OR it with the last address in the subnet
          # Calculate the last address via mask bit math
          @network_broadcast_address_int ||= (_network_address_obj.to_i | (2**(32 - prefix) - 1))
          return true if other_address_obj.to_i == @network_broadcast_address_int

          return false
        end

        # other_multicast is more for parity with other_broadcast and convenience, as the address we'll need to check will just be a string.
        def other_multicast?(other)
          _multicast_network_obj.include?(other)
        end

        def prefix
          _parse_cidr unless @prefix
          return @prefix
        end

        def proto
          @proto ||= _proto
        end

        def to_i
          _address_obj.to_i
        end

        def validate_proto(required_proto)
          return true if proto == required_proto.to_sym

          raise("Address #{address} did not validate as #{proto}")
        end

        private

        def _address_obj
          @address_obj ||= IPAddr.new(address)
        end

        def _multicast_network_cidr
          case proto
          when :ipv4
            '224.0.0.0/4' # RFC5735 / RFC3171
          when :ipv6
            'FF00::/8' # RFC5735 / RFC3171
          else
            raise("Unknown proto #{proto}")
          end
        end

        def _multicast_network_obj
          @multicast_network_obj ||= IPAddr.new(_multicast_network_cidr)
        end

        def _network_address_obj
          @network_address_obj ||= IPAddr.new(@cidr)
        end

        def _parse_cidr
          split_str = @cidr.split('/')
          raise(ArgumentError, "#{cidr} is not a valid CIDR") unless split_str.length == 2

          @address = split_str[0]
          @prefix = split_str[1].to_i
        end

        def _proto
          return :ipv4 if ipv4?
          return :ipv6 if ipv6?

          raise("Unknown proto")
        end
      end
    end
  end
end
