require './spec/helpers/spec_helper'
require './lib/tun_mesh/ipc/packet'

describe TunMesh::IPC::Packet do
  subject do
    described_class.new(
      data: SecureRandom.hex,
      internal_stamp: rand(1..(2**64))
    )
  end

  let(:binary_duplicated) { described_class.decode(subject.encode) }
  let(:json_duplicated) { described_class.from_json(subject.to_json) }

  describe 'r/w attributes' do
    test_config = {
      b64_data: %i[data data_length id md5 md5_raw],
      data:     %i[b64_data data_length id md5 md5_raw],
      internal_stamp: %i[stamp id md5 md5_raw],
      stamp:    %i[internal_stamp id md5 md5_raw],
    }

    test_config.each_pair do |attr_name, dependent_attrs|
      independent_attrs = ((%i[version] + test_config.keys) - (dependent_attrs + [attr_name]))

      describe attr_name.to_s do
        let(:test_attr_name) { attr_name }
        let(:new_data) { Array.new(rand(2..5)) { SecureRandom.hex }.join }

        
        let(:test_value) do
          case attr_name
          when :b64_data
            Base64.encode64(new_data)
          when :data
            new_data
          when :internal_stamp
            rand(1..(2**64))
          when :stamp
            rand * (2**32)
          else
            raise("INTERNAL ERROR: unknown attribute #{test_attr}")
          end
        end

        it 'is settable' do
          expect(subject.send(test_attr_name)).to_not eq test_value
          subject.send("#{test_attr_name}=", test_value)
          expect(subject.send(test_attr_name)).to eq test_value
        end

        it 'serializes via binary' do
          subject.send("#{test_attr_name}=", test_value)
          expect(binary_duplicated.send(test_attr_name)).to eq test_value
        end

        it 'serializes via json' do
          subject.send("#{test_attr_name}=", test_value)
          expect(json_duplicated.send(test_attr_name)).to eq test_value
        end

        dependent_attrs.each do |dependent_attr|
          it "updates #{dependent_attr}" do
            orig_dependent_attr = subject.send(dependent_attr).to_s
            expect(subject.send(dependent_attr).to_s).to eq orig_dependent_attr
            subject.send("#{test_attr_name}=", test_value)
            expect(subject.send(dependent_attr).to_s).to_not eq orig_dependent_attr
            expect(subject.send(dependent_attr).to_s).to_not eq test_value.to_s
          end
        end

        independent_attrs.each do |independent_attr|
          it "does not update #{independent_attr}" do
            orig_independent_attr = subject.send(independent_attr).to_s
            subject.send("#{test_attr_name}=", test_value)
            expect(subject.send(independent_attr).to_s).to eq orig_independent_attr
            expect(subject.send(independent_attr).to_s).to_not eq test_value.to_s
          end
        end
      end
    end
  end

  describe 'serialization' do
    shared_examples 'deserialize failure' do
      it 'fails to deserialize' do
        expect { deserialized_output }.to raise_exception(described_class::PayloadError)
      end
    end

    describe 'binary' do
      {
        version: 0,
        data_length: 1,
        data: 4,
        md5_raw: 36,
        internal_stamp: 56
      }.each do |attr_name, poke_index|
        describe "when #{attr_name} is incorrect" do
          let(:bad_serialized_value) do
            initial_serialized_value = subject.encode
            initial_serialized_value[poke_index] = (initial_serialized_value[poke_index].ord ^ 0xff).chr
            initial_serialized_value
          end

          let(:deserialized_output) { described_class.decode(bad_serialized_value) }
          
          it_behaves_like 'deserialize failure'
        end
      end
    end
    
    describe 'json' do
      let(:initial_deserialzed_input) { JSON.parse(subject.to_json) }
      let(:test_overrides) { {} }
      let(:bad_serialized_input) do
        JSON.dump(initial_deserialzed_input.merge(test_overrides))
      end

      let(:deserialized_output) { described_class.from_json(bad_serialized_input) }

      TunMesh::IPC::Packet.new.to_h.keys.each do |attr_name|
        describe "when #{attr_name} is incorrect" do
          let(:test_value) do
            case attr_name
            when :internal_stamp
              rand(0..2**64)
            else
              SecureRandom.hex
            end
          end

          let(:test_overrides) { { attr_name => test_value } }
          it_behaves_like 'deserialize failure'
        end

        describe "when #{attr_name} is missing" do
          let(:initial_deserialzed_input) { JSON.parse(subject.to_json).reject { |k| k == attr_name.to_s } }
          it_behaves_like 'deserialize failure'
        end
      end
    end
  end
end
