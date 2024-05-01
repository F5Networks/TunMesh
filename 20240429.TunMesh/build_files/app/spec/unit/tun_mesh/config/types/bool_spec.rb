require './spec/helpers/spec_helper'
require './lib/tun_mesh/config/errors'
require './lib/tun_mesh/config/types/bool'
require './spec/support/shared_examples/tun_mesh/config/types/type_base'

describe TunMesh::Config::Types::Bool do
  let(:subject_type) { 'bool' }
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

  describe '.load_config_value' do
    describe 'parsing' do
      it 'supports TrueClass' do
        subject.load_config_value(value: true)
        expect(subject.value).to eq true
      end

      it 'supports FalseClass' do
        subject.load_config_value(value: false)
        expect(subject.value).to eq false
      end

      {
        'true' => true,
        'True' => true,
        'TRUE' => true,
        'trUe' => true,
        'false' => false,
        'False' => false,
        'FALSE' => false,
        'faLse' => false
      }.each do |test_input, test_output|
        it "supports #{description} strings" do
          subject.load_config_value(value: test_input)
          expect(subject.value).to eq test_output
        end
      end
    end
  end
end
