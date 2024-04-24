Testing Local: Early Dev
=============

Control Plane
-------------

- Start first, it launches the Sysv IPC MQ queues
- Each instance needs a unique config
-- examples in `etc/test_config`

### Control 1

```
docker build . && docker run --rm -ti --name=control1 --ipc=shareable -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.1.yaml -p 4567:4567 $(docker build -q .) bundle exec ./bin/control_api.rb
```

### Control 2

- Note NAT

```
docker build . && docker run --rm -ti --name=control2 --ipc=shareable -v $(pwd)/etc/test_config:/etc/tunmesh:ro -e TUNMESH_CONFIG_PATH=/etc/tunmesh/config.2.yaml -p 4568:4567 $(docker build -q .) bundle exec ./bin/control_api.rb
```

Tun
---

### Tun1

```
docker build . && docker run --rm -ti -u 0:0 --name=tun1 --ipc=container:control1 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config/config.1.yaml:/etc/tunmesh/config.yaml:ro $(docker build -q .) bundle exec bin/tun_handler.rb
```

### Tun2

```
docker build . && docker run --rm -ti -u 0:0 --name=tun2 --ipc=container:control2 --device=/dev/net/tun --cap-add=cap_net_admin --cap-add=cap_net_raw -v $(pwd)/etc/test_config/config.2.yaml:/etc/tunmesh/config.yaml:ro $(docker build -q .) bundle exec bin/tun_handler.rb
```

