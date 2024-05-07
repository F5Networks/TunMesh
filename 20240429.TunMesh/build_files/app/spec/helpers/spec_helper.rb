require 'securerandom'
require 'simplecov'

SimpleCov.start do
  enable_coverage :branch

  # Container handler: In the container coverage/ may not be writable.
  begin
    coverage_path = Pathname.new('coverage')
    Dir.mkdir(coverage_path) unless coverage_path.directory?
    FileUtils.touch(coverage_path.join('index.html'))
  rescue StandardError => exc
    coverage_path = Dir.mktmpdir('coverage')
    warn("coverage/ directory not writable (#{exc}), writing coverage report to #{coverage_path}")
  end
  coverage_dir(coverage_path)
end

require './lib/tun_mesh/config'
TunMesh::CONFIG.stub!
