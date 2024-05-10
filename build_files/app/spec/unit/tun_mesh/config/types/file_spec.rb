require './spec/helpers/spec_helper'
require './lib/tun_mesh/config/errors'
require './lib/tun_mesh/config/types/file'
require './spec/support/shared_examples/tun_mesh/config/types/type_base'

# Incomplete
describe TunMesh::Config::Types::File do
  let(:subject_type) { 'file path' }
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

  describe 'when the default is nil and required is false' do
    let(:subject_test_args) do
      {
        default: nil,
        required: false
      }
    end

    describe '.required' do
      it 'returns false' do
        expect(subject.required).to eq(false)
      end
    end

    describe '.value' do
      it 'returns nil' do
        expect(subject.value).to be_nil
      end
    end
  end

  describe '.load_config_value' do
    let(:mock_config_obj) do
      # config_path is the config file path, actual base is this.dirname
      OpenStruct.new(config_path: Pathname.new('spec/unit'))
    end

    it 'fails when passed a nonexistent file' do
      expect { subject.load_config_value(value: SecureRandom.hex, config_obj: mock_config_obj) }.to raise_exception(TunMesh::Config::Errors::ValueError)
    end

    it 'fails when passed a non-file' do
      expect { subject.load_config_value(value: 'unit', config_obj: mock_config_obj) }.to raise_exception(TunMesh::Config::Errors::ValueError)
    end

    it 'supports relative paths to the config file path' do
      subject.load_config_value(value: 'helpers/spec_helper.rb', config_obj: mock_config_obj)
      expect(subject.value).to be_a(Pathname)
      expect(subject.value).to eq(Pathname.new('spec/helpers/spec_helper.rb'))
    end

    it 'supports relative paths below the config file path' do
      subject.load_config_value(value: '../Gemfile', config_obj: mock_config_obj)
      expect(subject.value).to be_a(Pathname)
      expect(subject.value).to eq(Pathname.new('Gemfile'))
    end

    it 'supports absolure paths' do
      subject.load_config_value(value: '/etc/resolv.conf', config_obj: mock_config_obj)
      expect(subject.value).to be_a(Pathname)
      expect(subject.value).to eq(Pathname.new('/etc/resolv.conf'))
    end
  end
end
