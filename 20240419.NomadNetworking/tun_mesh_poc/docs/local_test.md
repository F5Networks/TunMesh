Testing Local: Early Dev
=============

Control Plane
-------------

- Start first, it launches the Sysv IPC MQ queues
- Each instance needs a unique config
-- examples in `etc/test_config`

### Tunnel 1

```
docker build . && docker run --rm -ti --name=tm1 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.1.yaml -p 4567:4567 $(docker build -q .)
```

### Tunnel 2

- Note NAT

```
docker build . && docker run --rm -ti --name=tm2 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.2.yaml -p 4568:4567 $(docker build -q .)
```
