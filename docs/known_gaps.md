Known Gaps
==========

Alas, no solution is perfect.
This page documents the known gaps, why they are gaps, and possible development paths forward.

IPv6 Support
------------

This application has IPv6 decoding support and the baseline framework to support IPv6.
The primary gap is local IP handling, there is currently not a way to support setting a IPv6 IP on the tun device.
This is a [documented restriction in the tun library currently in use](https://github.com/amoghe/rb_tuntap/blob/bb99ca77a24696d6b671cc4fd7d8b9a6d05333ea/lib/rb_tuntap.rb#L95-L97).

### Possible short term fix

Short term solution would be to piggy-back on the IPv6 link address added automatically to the device.
The application will need to be modified to determine the ControlPlane::Structs::NodeInfo node_addresses values by gathering the interface addresses via the Socket class instead of simply advertising the config.
Different local and mesh subnets would not be supported.

### Possible long term fix

- Apply the `Advanced Config` fix below.
- Use the new config support to set IPv6 interface IPs, same as IPv4.

UDP mesh interprocess/WAN traffic support
-------------------------------------

Currently all mesh traffic is sent between nodes over the control API via HTTP POST calls.
This was done as it is fast to implement, reliable, and secure.
However, it is not performant and running TCP within TCP has known potential issues.

Note that this is referring to Tun Mesh nodes forwarding traffic between nodes over UDP.
UDP over the tunnels is fully supported.

### Possible Fix

The main hurdle to adding a UDP listener is the loss of TLS protections the API gives us.
Sending traffic in the clear violates the "secure by default" design goal of this app, and the JWT auth pattern in current use is not compatible with clear communications channels.

To add UDP support the app will need to be modified to:

- Add a UDP socket listener, this is trivial.
  - This should use a separate process like the tun handler
- Add a new IPC packet class for UDP IPC that encrypts the payload using symmetric encryption.
  - The API session secret may or may not be reusable for this case.

Advanced Configuration Support
------------------------------

Currently the app only supports adding a basic, IPv4 IP to the tun device.
No other config is supported.

### Possible Fix

- Modify the program to use the `ip` utility to set up the tunnel.
  - Set the tunnel IP via the `ip` command and not the `rb_tuntap` library.
- Extend the config to take a script of commands from the user (trusted config) to allow extending.

IPv4 Local Broadcast IP support
-------------------------------

The app currently sets up the tun device with the local IPv4 address and the mesh subnet mask.
This causes all mesh subnet traffic to go to the tunnel, where local vs mesh is determined in the Tun Mesh application.
As such the local subnet broadcast address doesn't work, as it appears like any other unicast address to the kernel.

### Possible Fix

- Apply the `Advanced Config` fix above to allow setting routes.
- Add the tun device address using the local subnet mask.
- Add a route for the mesh.
- Remove software block on the local broadcast IP in the VPN::Router class.

Multicast Support
-----------------

Multicast support requires the routers to listen for IGMP packets and build routing tables accordingly.
This is not implemented as multicast support is orders of magnitude more complex to implement than unicast.

General Performance
-------------------

This application is currently written fully in Ruby for development speed.
Performance optimizations have not been evaluated.
Threads are currently used where select() may be better, and some components like the tun_handler may be better implemented in a lower level language like Rust.
Ruby has a global interpreter lock which can bottleneck on high IO applications.
