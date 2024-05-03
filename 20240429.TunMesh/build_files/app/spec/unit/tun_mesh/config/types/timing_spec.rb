require './spec/helpers/spec_helper'
require './lib/tun_mesh/config/errors'
require './lib/tun_mesh/config/types/timing'
require './spec/support/shared_examples/tun_mesh/config/types/type_base'

describe TunMesh::Config::Types::Timing do
  let(:subject_type) { 'timing' }
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
      let(:subject_test_args) { { max: 10**10 } }

      it 'supports integers' do
        test_value = rand(1..10000)
        subject.load_config_value(value: test_value)
        expect(subject.value).to eq test_value
      end

      it 'supports floats' do
        test_value = rand(1.0..10000.0)
        subject.load_config_value(value: test_value)
        expect(subject.value).to eq test_value
      end

      {
        bare: { suffix: '', scalar: 1 },
        seconds: { suffix: 's', scalar: 1 },
        minutes: { suffix: 'm', scalar: 60 },
        hours: { suffix: 'h', scalar: 3600 },
        days: { suffix: 'd', scalar: 86400 }
      }.each do |description, config|
        it "supports #{description} exact strings" do
          test_rand_input = rand(1.0..10000.0)
          test_value_input = "#{test_rand_input}#{config[:suffix]}"
          test_value_output = test_rand_input * config[:scalar]
          subject.load_config_value(value: test_value_input)
          expect(subject.value).to eq test_value_output
        end

        it "supports #{description} range strings" do
          test_rand_input_low = rand(1.0..5000.0)
          test_rand_input_high = rand(test_rand_input_low..10000.0)
          test_value_input = "#{test_rand_input_low}..#{test_rand_input_high}#{config[:suffix]}"
          test_value_output_low = test_rand_input_low * config[:scalar]
          test_value_output_high = test_rand_input_high * config[:scalar]
          subject.load_config_value(value: test_value_input)
          expect(subject.value).to be >= test_value_output_low
          expect(subject.value).to be <= test_value_output_high
        end
      end
    end

    describe 'min value' do
      it 'defaults to blocking low values' do
        expect { subject.load_config_value(value: 0.4) }.to raise_exception(TunMesh::Config::Errors::ValueError)
      end

      it 'is tunable' do
        test_limit = rand(1.0..3599.0)
        subject_test_args[:min] = test_limit
        expect { subject.load_config_value(value: (test_limit - 0.001)) }.to raise_exception(TunMesh::Config::Errors::ValueError)
        expect { subject.load_config_value(value: (test_limit + 0.001)) }.to_not raise_exception
      end
    end

    describe 'max value' do
      it 'defaults to blocking hour+ values' do
        expect { subject.load_config_value(value: 3600.001) }.to raise_exception(TunMesh::Config::Errors::ValueError)
      end

      it 'is tunable' do
        test_limit = rand(1.0..10000.0)
        subject_test_args[:max] = test_limit
        expect { subject.load_config_value(value: (test_limit + 0.001)) }.to raise_exception(TunMesh::Config::Errors::ValueError)
        expect { subject.load_config_value(value: (test_limit - 0.001)) }.to_not raise_exception
      end
    end
  end
end
