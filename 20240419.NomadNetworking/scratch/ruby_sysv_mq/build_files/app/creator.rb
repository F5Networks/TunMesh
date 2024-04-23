#!/usr/bin/env ruby

require 'sysvmq'

begin
  # Arg 0: Queue ID: msgget(2) arg 0
  # Arg 1: Internal buffer size: Ruby sysvmq extension
  # Arg 2: flags: msgget(2) arg 1
  mq = SysVMQ.new(0xDEADC0DE, 1024, (SysVMQ::IPC_CREAT | SysVMQ::IPC_EXCL | 0o660))

  loop do
    mq.send(Time.now.to_s)
    sleep(1)

    # Raise an exception instead of blocking until a message is available
    # Arg 0: Int flag, undocumented.  0 does default behavior.
#    puts mq.receive(0, SysVMQ::IPC_NOWAIT)
  end
ensure
  # Delete queue
  mq&.destroy
end
