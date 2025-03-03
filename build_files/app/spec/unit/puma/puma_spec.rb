require './spec/helpers/spec_helper'
require 'puma'

describe Puma do
  it 'was compiled with SSL support' do
    expect(described_class::HAS_SSL).to eq true
  end
end
