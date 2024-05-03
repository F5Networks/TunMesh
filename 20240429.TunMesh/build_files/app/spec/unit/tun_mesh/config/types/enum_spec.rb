require './spec/helpers/spec_helper'
require './lib/tun_mesh/config/errors'
require './lib/tun_mesh/config/types/enum'
require './spec/support/shared_examples/tun_mesh/config/types/type_base'

# Incomplete
xdescribe TunMesh::Config::Types::Enum do
  let(:subject_type) { 'enum' }
  let(:subject_base_args) do
    {
      description_short: SecureRandom.hex,
      key: SecureRandom.hex
    }
  end

  let(:subject_test_args) { {} }
  let(:test_default_value) { SecureRandom.hex }

  subject { described_class.new(**subject_base_args.merge(subject_test_args)) }

  it_behaves_like 'type_base'

  pending '.load_config_value'
end