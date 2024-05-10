require './spec/helpers/spec_helper'

shared_examples 'type_base' do
  it_behaves_like 'type_base_description'
  it_behaves_like 'type_base_example'
  it_behaves_like 'type_base_common'
end

shared_examples 'type_base_description' do
  describe '.description_type' do
    it 'returns the type' do
      expect(subject.description_type).to eq(subject_type)
    end
  end

  describe 'when a default is set' do
    let(:subject_test_args) { { default: test_default_value } }

    describe '.default_description' do
      it 'returns "Default value: [default]"' do
        expect(subject.default_description).to eq("Default value: #{subject_test_args[:default]}")
      end
    end

    describe '.description_block_lines' do
      describe 'without description_long' do
        it 'returns the main description line and default' do
          expected_value = [
            "[Optional] #{subject_base_args[:key]} (#{subject_type}): #{subject_base_args[:description_short]}",
            "Default value: #{subject_test_args[:default]}"
          ]
          expect(subject.description_block_lines).to eq(expected_value)
        end
      end

      describe 'with description_long' do
        let(:subject_test_args) do
          {
            default: test_default_value,
            description_long: Array.new(rand(3..9)) { SecureRandom.hex }.join("\n")
          }
        end

        it 'returns the main description line, long description, and default' do
          expected_value = ["[Optional] #{subject_base_args[:key]} (#{subject_type}): #{subject_base_args[:description_short]}"]
          expected_value += subject_test_args[:description_long].split("\n")
          expected_value.push("Default value: #{subject_test_args[:default]}")
          expect(subject.description_block_lines).to eq(expected_value)
        end
      end
    end

    describe '.description_type' do
      it 'returns the type' do
        expect(subject.description_type).to eq(subject_type)
      end
    end
  end

  describe 'when a default is absent' do
    describe '.default_description' do
      it 'returns nil' do
        expect(subject.default_description).to be_nil
      end
    end

    describe '.description_block_lines' do
      describe 'without description_long' do
        it 'returns the main description line' do
          expected_value = [
            "[REQUIRED] #{subject_base_args[:key]} (#{subject_type}): #{subject_base_args[:description_short]}"
          ]
          expect(subject.description_block_lines).to eq(expected_value)
        end
      end

      describe 'with description_long' do
        let(:subject_test_args) do
          {
            description_long: Array.new(rand(3..9)) { SecureRandom.hex }.join("\n")
          }
        end

        it 'returns the main description line, long description, and default' do
          expected_value = ["[REQUIRED] #{subject_base_args[:key]} (#{subject_type}): #{subject_base_args[:description_short]}"]
          expected_value += subject_test_args[:description_long].split("\n")
          expect(subject.description_block_lines).to eq(expected_value)
        end
      end
    end
  end
end

shared_examples 'type_base_example' do
  shared_examples 'type_base_example_example_config_lines_common' do
    it 'includes the description_block_lines prefixed with "# "' do
      description_block_lines = subject.description_block_lines
      expect(subject.example_config_lines[0..(description_block_lines.length - 1)]).to eq(description_block_lines.map { |l| "# #{l}" })
    end

    it 'includes the example_value_lines' do
      example_value_lines = subject.example_value_lines
      expect(subject.example_config_lines[-example_value_lines.length..-1]).to eq example_value_lines
    end
  end

  describe 'when a default is set' do
    let(:subject_test_args) { { default: test_default_value } }

    describe '.example_config_lines' do
      it 'comments out all the lines' do
        subject.example_config_lines.each do |line|
          expect(line[0..1]).to eq('# ')
        end
      end

      it_behaves_like 'type_base_example_example_config_lines_common'
    end

    describe '.example_value_lines' do
      it 'returns the key and default commented out' do
        expect(subject.example_value_lines).to eq(["# #{subject_base_args[:key]}: #{subject_test_args[:default]}"])
      end
    end
  end

  describe 'when a default is absent' do
    describe '.example_config_lines' do
      it_behaves_like 'type_base_example_example_config_lines_common'
    end

    describe '.example_value_lines' do
      it 'returns the key and a placeholder' do
        expect(subject.example_value_lines).to eq(["#{subject_base_args[:key]}: [Deployment Unique Value]"])
      end
    end
  end
end

shared_examples 'type_base_common' do
  describe 'when a default is set' do
    let(:subject_test_args) { { default: test_default_value } }

    describe '.required' do
      it 'returns false' do
        expect(subject.required).to eq false
      end
    end

    describe 'when no value has been loaded' do
      describe '.to_s' do
        it 'returns the default' do
          expect(subject.to_s).to eq(subject_test_args[:default].to_s)
        end
      end

      describe '.value' do
        it 'returns the default' do
          expect(subject.value).to eq(subject_test_args[:default])
        end
      end
    end
  end

  describe 'when a default is absent' do
    describe '.required' do
      it 'returns true' do
        expect(subject.required).to eq true
      end
    end

    describe 'when no value has been loaded' do
      describe '.to_s' do
        it 'returns an empty string' do
          expect(subject.to_s).to eq('')
        end
      end

      describe '.value' do
        it 'returns nil' do
          expect(subject.value).to be_nil
        end
      end
    end
  end
end
