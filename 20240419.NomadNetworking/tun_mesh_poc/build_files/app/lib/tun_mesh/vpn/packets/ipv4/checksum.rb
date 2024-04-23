module TunMesh
  module VPN
    module Packets
      module IPv4
        module Checksum
          def self.generate(contents, mask_index)
            # https://en.wikipedia.org/wiki/IPv4_header_checksum
            content_sum = contents.chars.each_slice(2).to_a.map.with_index do |chunk, index|
              if (index * 2) == mask_index
                0
              else
                chunk[0].ord << 8 | chunk[1].ord
              end
            end.sum
            carry_result = (content_sum & 0xffff) + ((content_sum & 0xf0000) >> 16)
            return carry_result ^ 0xffff
          end
        end
      end
    end
  end
end
    
