require 'spec_helper'

describe Sidekiq::Datadog do
  it 'has a version' do
    expect(described_class::VERSION).to be_instance_of(String)
  end
end
