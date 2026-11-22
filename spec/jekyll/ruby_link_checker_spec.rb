# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker do
  it 'has a semantic version' do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
