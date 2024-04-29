Supported Protocols And Patterns
================================

This app supports Layer 3 networking protocols, namely IP.

As this application implements basic layer 3 routing first class protocol support is required.
Any protocols not in this list are not supported.

IPv4
----

**Supported**

IPv4 is supported with full unicast support.
Faux routing is supported where nodes can be classified as `local` and `mesh`, with `local` nodes supporting lower timeouts and faster re-registration intervals.

All IPv4 IPs are routed by the kernel as a flat network, `local` vs `mesh` subnetting is done entirely in the Tun Mesh application.

| IPv4 Packet Type                           | Supported | Note |
| ------------------------------------------ | --------- | ---- |
| Unicast                                    | Yes       |      |
| Broadcast - 255.255.255.255                | Yes       | Will broadcast to the local subnet.  Disabled by default. |
| Broadcast - Local subnet broadcast address | No        | Not technically possible with current tun setup. Use 255.255.255.255. |
| Broadcast - Mesh subnet broadcast address  | Yes       | Will broadcast to all nodes in the mesh.  Disabled by default. |
| Multicast                                  | No        | Not supported. |

**Note:** Broadcast IPs usage likely requires broadcast support to be enabled on the host.

IPv6
----

**Unsupported**

See [docs/known_gaps.md](docs/known_gaps.md)
