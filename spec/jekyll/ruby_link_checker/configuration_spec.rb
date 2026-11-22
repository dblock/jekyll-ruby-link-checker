# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Configuration do
  def config(raw)
    described_class.new(raw)
  end

  it 'has defaults' do
    defaults = config(nil)

    expect(defaults).to have_attributes(concurrency: 5, retries: 1, user_agent: nil, verbose?: false)
    expect(defaults.cache).to have_attributes(file: nil, ttl: 30 * 86_400)
    expect(defaults.exclude).to have_attributes(domains: [], urls: [], paths: [])
  end

  it 'reads all options' do
    configured = config(
      'cache' => { 'file' => '.cache/links.json', 'ttl' => '12h' },
      'exclude' => { 'domains' => ['Example.COM'], 'urls' => ['https://example.org/'], 'paths' => ['^/tags'] },
      'concurrency' => 2,
      'retries' => 0,
      'user_agent' => 'Test Checker',
      'verbose' => true
    )

    expect(configured).to have_attributes(concurrency: 2, retries: 0, user_agent: 'Test Checker', verbose?: true)
    expect(configured.cache).to have_attributes(file: '.cache/links.json', ttl: 12 * 3600)
    expect(configured.exclude).to have_attributes(domains: ['example.com'], urls: ['https://example.org/'])
    expect(configured.exclude.paths).to eq([%r{^/tags}])
  end

  it 'reads durations' do
    expect(described_class.duration(90, 'ttl')).to eq(90)
    expect(described_class.duration('45', 'ttl')).to eq(45)
    expect(described_class.duration('2w', 'ttl')).to eq(2 * 604_800)
    expect(described_class.duration(' 30 d ', 'ttl')).to eq(30 * 86_400)
  end

  it 'rejects invalid durations' do
    ['1y', '0', 0, -5, '', nil].each do |value|
      expect { described_class.duration(value, 'cache.ttl') }
        .to raise_error(Jekyll::Errors::InvalidConfigurationError, /link_checker.cache.ttl must be a positive/)
    end
  end

  it 'rejects unknown options with the valid ones' do
    expect { config('excludes' => {}) }.to raise_error(
      Jekyll::Errors::InvalidConfigurationError,
      'Unknown link_checker option: excludes. Valid options: cache, exclude, concurrency, retries, user_agent, verbose'
    )
  end

  it 'rejects unknown section options with the valid ones' do
    expect { config('cache' => { 'path' => 'x' }) }.to raise_error(
      Jekyll::Errors::InvalidConfigurationError,
      'Unknown link_checker.cache option: path. Valid options: file, ttl'
    )
  end

  it 'rejects options of the wrong type' do
    [
      [{ 'link_checker' => true }],
      { 'cache' => 'file.json' },
      { 'exclude' => { 'domains' => 'example.com' } },
      { 'exclude' => { 'paths' => ['('] } },
      { 'concurrency' => 0 },
      { 'concurrency' => '5' },
      { 'retries' => -1 }
    ].each do |raw|
      expect { config(raw) }.to raise_error(Jekyll::Errors::InvalidConfigurationError, /link_checker/)
    end
  end
end
