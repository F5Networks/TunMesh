require 'logger'
require 'pathname'

require_relative './named_pipe/packet'

module TunMesh
  class NamedPipe
    def initalize(init_pipe:, path:)
      @logger = Logger.new(STDERR, progname: "#{self.class}(#{path})")
      @path_obj = Pathname.new(path)
      
      _init_pipe if init_pipe
    end

    def read_loop
      File.open(@path_obj.to_s, File::RDONLY) do |pipe|
        packet = Packet.decode(pipe)
        @logger.debug { "Read #{packet.md5} / #{packet.data_length}b" }
        yield packet
      end
    end

    def write_loop
      File.open(@path_obj.to_s, File::WRONLY) do |pipe|
        loop do
          data = yield
          break if data.nil?

          packet = Packet.new(data: data)
          @logger.debug { "Sending #{packet.md5} / #{packet.data_length}b" }

          bytes_written = pipe.write(packet.encode)
          raise("#{@path_obj}: Partial Write: Only wrote #{bytes_written}/#{packet.data_length}b")if bytes_written != packet.data_length
        end
      end
    end

    private

    def _init_pipe
      if @path_obj.pipe?
        @logger.debug('Pipe exists')
        return
      end

      raise("Non-pipe exists at target path #{@path_obj}") if @path_obj.exist?

      @logger.info("#{@log_prefix}: Creating pipe")
      File.mkfifo(@path_obj.to_s)
      
      raise('Pipe does not exist after create') unless @path_obj.pipe?

      # The File.mkfifo() mode arg doesn't seem to work, explicitly chmod the pipe
      # Leaving the mod hardcoded, it's app specific and highly unlikely to need to be tuned
      @path_obj.chmod(0o660)
      @logger.debug("#{@log_prefix}: Pipe mode: #{@path_obj.stat.mode.to_s(8)}")
    end

    # This name doesn't match intentionally.
    # This method is only intended to be called once, @worker ||= is a safety to prevent parallel threads / thread loss.
    # rubocop: disable Naming/MemoizedInstanceVariableName
    def _init_worker
      last_fast_fault = 0
      @worker ||= Thread.new do
        @worker_healthy = true
        loop do
          @logger.debug("#{@log_prefix}: File loop iterating")
          File.open(@path_obj.to_s, File::RDONLY) do |f|
            loop do
              # Using read_nonblock() instead of read() as read() was blocking indefinitely.
              # read_nonblock() allows us to recheck for lines less than the block size on an interval via the exception handler
              _process_chunk(f.read_nonblock(256))
              @worker_healthy = true
            rescue Errno::EWOULDBLOCK
              sleep(SDCSTSSOTerminationMonitor::Config::Timing::PipeReader.blocking_delay)
            end
          end
        rescue EOFError => exc
  end
end
      
