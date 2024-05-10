Tun Mesh: L3 Mesh VPN Container Sidecar
=======================================

Project State
-------------

- F5 Internal: Contains undisclosed IP (IDF01011)
- Incubating: Final location pending IDF01011 / open source decision
- Written with the intent of being a open source, externally published standalone module

Description
-----------

Tun Mesh is a Layer 3 mesh VPN intended for use as a sidecar to applications deployed in container orchestration platforms.
This application sets up a private, internal network between the different instances of the app.
The network is a layer 3 network capable of carrying any layer 4 or higher traffic transparently.

This implementation is container platform agnostic.
The deployment requirements are:

- The container deployment must use a [common network container](https://docs.docker.com/network/#container-networks) for all containers deployed as a single instance group.
  - NOTE: This is the Kubernetes "pause" container pattern.
- Must have a IPv4 subnet for internal use.
  - NOTE: Internal use only, the subnet does not need to be routable outside the containers.
  - This can be any locally routable IPv4 subnet.
- Must be able to assign a unique address to each within the internal subnet to each internal deployment group.
  - Dynamic addressing is not currently supported
- Every Tun Mesh container must have access to a listening TCP socket on every other Tun Mesh container in the deployment.
  - NAT friendly
- Must be able to set the listening Tun Mesh IP address and port number in the Tun mesh config file.
- The container must be started with `cap_net_admin` and `cap_net_raw` to configure the network settings.
  - The UID is changed from root to a non-root user internally after enabling the tunnel to limit network admin access scope.
  - See [docs/security.md](docs/security.md) for more details on the security model.
- The container must have access to the `/dev/net/tun` device on the host.
  - This is required to create the tunnel device in the container, the tunnel is added to the container network namespace not on the host.
- A SSL cert is required.
  - Self-signed certs are allowed.

Configuring
-----------

The Tun Mesh application uses a self-documenting config pattern.
To see a full example config, run the following:

```
docker build . && docker run --rm $(docker build -q .) bin/generate_tun_mesh_example_config
```

Required config options are marked as `REQUIRED`.

There is an additional `bin/parse_tun_mesh_config` command which parses and lints config.

Running
-------

Exact deployment details will be platform dependent.
See [docs/local_test.md](docs/local_test.md) for an example 3 node mesh running local.

Supported Protocols and Patterns
--------------------------------

See [docs/protocols_and_patterns.md](docs/protocols_and_patterns.md) for a list of the supported protocols and patterns.

Monitoring
----------

- A health endpoint is available at `/health`.
- Optional Prometheus based monitoring is supported, see the example config.

Security and Performance
------------------------

This app attempts to be secure by default without causing onerous deployment steps.
All application traffic is encrypted using a user-provided SSL cert via standard HTTP TLS patterns.
Nodes use a shared secret to authenticate to each other.
See [docs/security.md](docs/security.md) for more details on the security model.

This app currently does not support high bandwidth flows.
See [docs/known_gaps.md](docs/known_gaps.md) for more details.
