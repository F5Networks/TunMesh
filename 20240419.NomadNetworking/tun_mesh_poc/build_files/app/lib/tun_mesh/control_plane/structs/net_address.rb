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
          @netmask ||= IPAddr.new(IPAddr.new(@cidr).netmask.to_s).to_s
        end

        def prefix
          _parse_cidr unless @prefix
          return @prefix
        end

        def validate_proto(proto)
          case proto.to_sym
          when :ipv4
            return true if ipv4?
          when :ipv6
            return true if ipv6?
          end

          raise("Address #{address} did not validate as #{proto}")
        end
        
        private

        def _network_address_obj
          @network_address_obj ||= IPAddr.new(@cidr)
        end
        
        def _parse_cidr
          split_str = @cidr.split('/')
          raise(ArgumentError, "#{cidr} is not a valid CIDR") unless split_str.length == 2

          @address = split_str[0]
          @prefix = split_str[1].to_i
        end
      end
    end
  end
end
