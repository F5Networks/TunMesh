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
          # TODO: Keep pattern?
          return new(cidr: cidr)
        end

        def address
          _parse_cidr unless @address
          return @address
        end

        def netmask
          @netmask ||= IPAddr.new(IPAddr.new(@cidr).netmask.to_s).to_s
        end

        def prefix
          _parse_cidr unless @prefix
          return @prefix
        end

        private
        
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
