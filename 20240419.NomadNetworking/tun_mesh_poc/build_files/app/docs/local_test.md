Testing Local: Early Dev
=============

Early Dev
---------

- Control running native
- tun in container

Control Plane
-------------

- Start first, it launches the Sysv IPC MQ queues
- Each instance needs a unique config
-- control/advertise_url
-- control/listen_port
-- discovery/bootstrap_node_urls
-- internal/private_address_cidr # TODO <- Name
-- ipc/queue_id

```
export TUNMESH_CONFIG_PATH=$(pwd)/tmp/config.yaml
./bin/control_api.rb
```

