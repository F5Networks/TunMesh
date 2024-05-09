Testing Local
=============

Build the container
-------------------

```
docker build --tag tun_mesh .
```

Run the application
---------------

Note the `pause` containers.
These provide the common network environment within a group of deployed containers.

NOTE: The pause containers need to be manually cleaned up, see `Cleanup` section.

### Instance 1

```
docker run -d --name=tm1 -p 4567:4567 registry.k8s.io/pause
docker run --rm -ti --net=container:tm1 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.1.yaml tun_mesh
```

### Instance 2

- Note NAT on the port listener

```
docker run -d --name=tm2 -p 4568:4567 registry.k8s.io/pause
docker run --rm -ti --net=container:tm2 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.2.yaml tun_mesh
```

### Instance 3

- Note NAT on the port listener

```
docker run -d --name=tm3 -p 4569:4567 registry.k8s.io/pause
docker run --rm -ti --net=container:tm3 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.3.yaml tun_mesh
```

Send some traffic
-----------------

### Ping instance 3 from instance 1

- Note that this is running a new container in the `tm1` network namespace.
  - A application started with the same `net=` setting will have transparent IP access to the other nodes in the mesh via the internal IPs.

```
docker run --rm -ti --net=container:tm1 tun_mesh ping 192.168.129.30
```

Cleanup
-------

### Remove the running `pause` containers

```
docker rm -f tm1 tm2 tm3
```

