Creator
-------

- Set up to create a new queue exclusively
- In docker needs `--ipc=shareable` to allow the consumer to access the queue

```
docker build . && docker run --name ipc_main --rm -ti --ipc=shareable $(docker build -q .) bundle exec /app/creator.rb
```

Consumer
--------

- Opens the queue, fails if it doesn't exist
- Registers into the creator IPC namespace

```
docker build . && docker run --rm -ti --ipc=container:ipc_main $(docker build -q .) bundle exec /app/consumer.rb
```
