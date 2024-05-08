require 'logger'
require_relative 'config'

module TunMesh
  class Logger < ::Logger
    # Minimal MVP logger implementation
    def initialize(id:)
      super($stderr, level: TunMesh::CONFIG.values.logging.level, progname: "#{_thread_id}: #{id}")
    end

    private

    def _thread_id
      Thread.current.to_s[2..].split[0]
    end
  end
end
