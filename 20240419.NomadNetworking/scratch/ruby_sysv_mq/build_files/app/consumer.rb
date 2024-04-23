#!/usr/bin/env ruby

require 'sysvmq'

# Arg 0: Queue ID: msgget(2) arg 0
# Arg 1: Internal buffer size: Ruby sysvmq extension
# Arg 2: flags: msgget(2) arg 1
mq = SysVMQ.new(0xDEADC0DE, 1024, 0)

loop do
  # Raise an exception instead of blocking until a message is available
  # Arg 0: Int flag, undocumented.  0 does default behavior.
  puts mq.receive(0)
end
