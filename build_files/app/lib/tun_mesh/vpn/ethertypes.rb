require_relative 'packets/ip/ipv4'
require_relative 'packets/ip/ipv6'

module TunMesh
  module VPN
    # rubocop: disable Layout/LineLength
    module Ethertypes
      # Generated from https://www.iana.org/assignments/ieee-802-numbers/ieee-802-numbers.xhtml#ieee-802-numbers-1 2024-04-29
      # Ranges are omitted
      # File.write('ethertypes.tmp', HTTParty.get('https://www.iana.org/assignments/ieee-802-numbers/ieee-802-numbers-1.csv')[1..-1].map { |r| [r[1], r[4]] }.to_h.reject { |k, v| k =~ /-/ || v.downcase =~ /invalid/ }.map { |k,v| "0x#{k} => '#{v}'," }.join("\n"))
      ETHERTYPES = {
        0x0600 => 'XEROX NS IDP',
        0x0660 => 'DLOG',
        0x0661 => 'DLOG',
        0x0800 => 'Internet Protocol version 4 (IPv4)',
        0x0801 => 'X.75 Internet',
        0x0802 => 'NBS Internet',
        0x0803 => 'ECMA Internet',
        0x0804 => 'Chaosnet',
        0x0805 => 'X.25 Level 3',
        0x0806 => 'Address Resolution Protocol (ARP)',
        0x0807 => 'XNS Compatability',
        0x0808 => 'Frame Relay ARP',
        0x081C => 'Symbolics Private',
        0x0900 => 'Ungermann-Bass net debugr',
        0x0A00 => 'Xerox IEEE802.3 PUP',
        0x0A01 => 'PUP Addr Trans',
        0x0BAD => 'Banyan VINES',
        0x0BAE => 'VINES Loopback',
        0x0BAF => 'VINES Echo',
        0x1000 => 'Berkeley Trailer nego',
        0x1600 => 'Valid Systems',
        0x22F3 => 'TRILL',
        0x22F4 => 'L2-IS-IS',
        0x4242 => 'PCS Basic Block Protocol',
        0x5208 => 'BBN Simnet',
        0x6000 => 'DEC Unassigned (Exp.)',
        0x6001 => 'DEC MOP Dump/Load',
        0x6002 => 'DEC MOP Remote Console',
        0x6003 => 'DEC DECNET Phase IV Route',
        0x6004 => 'DEC LAT',
        0x6005 => 'DEC Diagnostic Protocol',
        0x6006 => 'DEC Customer Protocol',
        0x6007 => 'DEC LAVC, SCA',
        0x6558 => 'Trans Ether Bridging',
        0x6559 => 'Raw Frame Relay',
        0x7000 => 'Ungermann-Bass download',
        0x7002 => 'Ungermann-Bass dia/loop',
        0x7030 => 'Proteon',
        0x7034 => 'Cabletron',
        0x8003 => 'Cronus VLN',
        0x8004 => 'Cronus Direct',
        0x8005 => 'HP Probe',
        0x8006 => 'Nestar',
        0x8008 => 'AT&T',
        0x8010 => 'Excelan',
        0x8013 => 'SGI diagnostics',
        0x8014 => 'SGI network games',
        0x8015 => 'SGI reserved',
        0x8016 => 'SGI bounce server',
        0x8019 => 'Apollo Domain',
        0x802E => 'Tymshare',
        0x802F => 'Tigan, Inc.',
        0x8035 => 'Reverse Address Resolution Protocol (RARP)',
        0x8036 => 'Aeonic Systems',
        0x8038 => 'DEC LANBridge',
        0x803D => 'DEC Ethernet Encryption',
        0x803E => 'DEC Unassigned',
        0x803F => 'DEC LAN Traffic Monitor',
        0x8044 => 'Planning Research Corp.',
        0x8046 => 'AT&T',
        0x8047 => 'AT&T',
        0x8049 => 'ExperData',
        0x805B => 'Stanford V Kernel exp.',
        0x805C => 'Stanford V Kernel prod.',
        0x805D => 'Evans & Sutherland',
        0x8060 => 'Little Machines',
        0x8062 => 'Counterpoint Computers',
        0x8065 => 'Univ. of Mass. @ Amherst',
        0x8066 => 'Univ. of Mass. @ Amherst',
        0x8067 => 'Veeco Integrated Auto.',
        0x8068 => 'General Dynamics',
        0x8069 => 'AT&T',
        0x806A => 'Autophon',
        0x806C => 'ComDesign',
        0x806D => 'Computgraphic Corp.',
        0x807A => 'Matra',
        0x807B => 'Dansk Data Elektronik',
        0x807C => 'Merit Internodal',
        0x8080 => 'Vitalink TransLAN III',
        0x809B => 'Appletalk',
        0x809F => 'Spider Systems Ltd.',
        0x80A3 => 'Nixdorf Computers',
        0x80C4 => 'Banyan Systems',
        0x80C5 => 'Banyan Systems',
        0x80C6 => 'Pacer Software',
        0x80C7 => 'Applitek Corporation',
        0x80D5 => 'IBM SNA Service on Ether',
        0x80DD => 'Varian Associates',
        0x80F2 => 'Retix',
        0x80F3 => 'AppleTalk AARP (Kinetics)',
        0x80F7 => 'Apollo Computer',
        0x80FF => 'Wellfleet Communications',
        0x8100 => 'Customer VLAN Tag Type (C-Tag, formerly called the Q-Tag) (initially Wellfleet)',
        0x8130 => 'Hayes Microcomputers',
        0x8131 => 'VG Laboratory Systems',
        0x8148 => 'Logicraft',
        0x8149 => 'Network Computing Devices',
        0x814A => 'Alpha Micro',
        0x814C => 'SNMP',
        0x814D => 'BIIN',
        0x814E => 'BIIN',
        0x814F => 'Technically Elite Concept',
        0x8150 => 'Rational Corp',
        0x817D => 'XTP',
        0x817E => 'SGI/Time Warner prop.',
        0x8180 => 'HIPPI-FP encapsulation',
        0x8181 => 'STP, HIPPI-ST',
        0x8182 => 'Reserved for HIPPI-6400',
        0x8183 => 'Reserved for HIPPI-6400',
        0x818D => 'Motorola Computer',
        0x81A4 => 'ARAI Bunkichi',
        0x86DB => 'SECTRA',
        0x86DE => 'Delta Controls',
        0x86DD => 'Internet Protocol version 6 (IPv6)',
        0x86DF => 'ATOMIC',
        0x876B => 'TCP/IP Compression',
        0x876C => 'IP Autonomous Systems',
        0x876D => 'Secure Data',
        0x8808 => 'IEEE Std 802.3 - Ethernet Passive Optical Network (EPON)',
        0x8809 => 'Slow Protocols (Link Aggregation, OAM, etc.)',
        0x880B => 'Point-to-Point Protocol (PPP)',
        0x880C => 'General Switch Management Protocol (GSMP)',
        0x8822 => 'Ethernet NIC hardware and software testing',
        0x8847 => 'MPLS',
        0x8848 => 'MPLS with upstream-assigned label',
        0x8861 => 'Multicast Channel Allocation Protocol (MCAP)',
        0x8863 => 'PPP over Ethernet (PPPoE) Discovery Stage',
        0x8864 => 'PPP over Ethernet (PPPoE) Session Stage',
        0x888E => 'IEEE Std 802.1X - Port-based network access control',
        0x88A8 => 'IEEE Std 802.1Q - Service VLAN tag identifier (S-Tag)',
        0x88B5 => 'IEEE Std 802 - Local Experimental Ethertype',
        0x88B6 => 'IEEE Std 802 - Local Experimental Ethertype',
        0x88B7 => 'IEEE Std 802 - OUI Extended Ethertype',
        0x88C7 => 'IEEE Std 802.11 - Pre-Authentication (802.11i)',
        0x88CC => 'IEEE Std 802.1AB - Link Layer Discovery Protocol (LLDP)',
        0x88E5 => 'IEEE Std 802.1AE - Media Access Control Security',
        0x88E7 => 'Provider Backbone Bridging Instance tag',
        0x88F5 => 'IEEE Std 802.1Q  - Multiple VLAN Registration Protocol (MVRP)',
        0x88F6 => 'IEEE Std 802.1Q - Multiple Multicast Registration Protocol (MMRP)',
        0x88F7 => 'Precision Time Protocol',
        0x890D => 'IEEE Std 802.11 - Fast Roaming Remote Request (802.11r)',
        0x8917 => 'IEEE Std 802.21 - Media Independent Handover Protocol',
        0x8929 => 'IEEE Std 802.1Qbe - Multiple I-SID Registration Protocol',
        0x893B => 'TRILL Fine Grained Labeling (FGL)',
        0x8940 => 'IEEE Std 802.1Qbg - ECP Protocol (also used in 802.1BR)',
        0x8946 => 'TRILL RBridge Channel',
        0x8947 => 'GeoNetworking as defined in ETSI EN 302 636-4-1',
        0x894F => 'NSH (Network Service Header)',
        0x9000 => 'Loopback',
        0x9001 => '3Com(Bridge) XNS Sys Mgmt',
        0x9002 => '3Com(Bridge) TCP-IP Sys',
        0x9003 => '3Com(Bridge) loop detect',
        0x9A22 => 'Multi-Topology',
        0xA0ED => 'LoWPAN encapsulation',
        # 0xB7EA => 'The Ethertype will be used to identify a "Channel" in which control messages are encapsulated as payload of GRE packets. When a GRE packet tagged with the Ethertype is received, the payload will be handed to the network processor for processing.',
        0xFF00 => 'BBN VITAL-LanBridge cache private protocol.',
        0xFFFF => 'Reserved'
      }.freeze

      def self.ethertype_name(ethertype:)
        ETHERTYPES.fetch(ethertype, format('[UNKNOWN ETHERTYPE 0x%04x]', ethertype))
      end

      def self.l3_packet_by_ethertype(ethertype:)
        case ethertype
        when Packets::IP::IPv4::ETHERTYPE
          return Packets::IP::IPv4
        when Packets::IP::IPv6::ETHERTYPE
          return Packets::IP::IPv6
        else
          return nil
        end
      end
    end
    # rubocop: enable Layout/LineLength
  end
end
