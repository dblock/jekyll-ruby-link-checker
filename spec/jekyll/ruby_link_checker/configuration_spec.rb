# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Configuration do
  def config(raw)
    described_class.new(raw)
  end

  it 'has defaults' do
    defaults = config(nil)

    expect(defaults).to have_attributes(concurrency: 5, retries: 1, user_agent: nil, verbose?: false,
                                        permanent_redirects?: false, layouts?: true)
    expect(defaults.cache).to have_attributes(file: nil, ttl: 30 * 86_400, blocked_ttl: nil, prune: false)
    expect(defaults.exclude).to have_attributes(domains: [], urls: [], paths: [])
  end

  it 'reads all options' do
    configured = config(
      'cache' => { 'file' => '.cache/links.json', 'ttl' => '12h', 'blocked_ttl' => '1d', 'prune' => true },
      'exclude' => { 'domains' => ['Example.COM'], 'urls' => ['https://example.org/'], 'paths' => ['^/tags'] },
      'concurrency' => 2,
      'retries' => 0,
      'user_agent' => 'Test Checker',
      'verbose' => true
    )

    expect(configured).to have_attributes(concurrency: 2, retries: 0, user_agent: 'Test Checker', verbose?: true)
    expect(configured.cache)
      .to have_attributes(file: '.cache/links.json', ttl: 12 * 3600, blocked_ttl: 86_400, prune: true)
    expect(configured.exclude).to have_attributes(domains: ['example.com'], urls: ['https://example.org/'])
    expect(configured.exclude.paths).to eq([%r{^/tags}])
    urls = config('exclude' => { 'urls' => ['https://example.org/', '/\Ahttps:\/\/x\.org\//', '/'] }).exclude.urls
    expect(urls.map { |url| [url.class, url.is_a?(Regexp) ? url.source : url] })
      .to eq([[String, 'https://example.org/'], [Regexp, '\Ahttps:\/\/x\.org\/'], [String, '/']])
  end

  it 'passes no request options by default, so ruby-link-checker keeps its defaults' do
    expect(config(nil).request_options).to eq({})
  end

  it 'reads request options with the names ruby-link-checker uses' do
    configured = config(
      'blocked' => [403, 999], 'detect_challenges' => false, 'timeout' => '90s', 'connect_timeout' => 5,
      'host_concurrency' => 2, 'host_interval' => 0.5, 'headers' => { 'Accept-Language' => 'en-US' },
      'host_headers' => { 'www.npmjs.com' => { 'Accept' => 'text/html' }, '/(\A|\.)medium\.com\z/' => { 'X' => 'y' } }
    )

    expect(configured.request_options).to eq(
      blocked_status_codes: [403, 999], detect_challenges: false, timeout: 90, connecttimeout: 5,
      max_concurrency_per_host: 2, min_host_interval: 0.5, headers: { 'Accept-Language' => 'en-US' },
      host_headers: { 'www.npmjs.com' => { 'Accept' => 'text/html' }, /(\A|\.)medium\.com\z/ => { 'X' => 'y' } }
    )
    expect(config('blocked' => false, 'host_interval' => '2s').request_options)
      .to eq(blocked_status_codes: [], min_host_interval: 2)
  end

  it 'rejects invalid request options, naming them' do
    {
      { 'blocked' => [403, 1000] } => 'link_checker.blocked must be false or a list of HTTP status codes',
      { 'blocked' => true } => 'link_checker.blocked must be',
      { 'detect_challenges' => 'no' } => 'link_checker.detect_challenges must be true or false',
      { 'timeout' => 0 } => 'link_checker.timeout must be',
      { 'host_concurrency' => 0 } => 'link_checker.host_concurrency must be a positive integer',
      { 'host_interval' => -1 } => 'link_checker.host_interval must be',
      { 'headers' => { 'Accept' => 1 } } => 'link_checker.headers must be a set of header names and values',
      { 'host_headers' => ['x.org'] } => 'link_checker.host_headers must be a set of hosts and their headers',
      { 'host_headers' => { 'x.org' => 'y' } } => 'link_checker.host_headers.x.org must be a set of header',
      { 'host_headers' => { '/(/' => {} } } => 'link_checker.host_headers must be a regular expression',
      { 'exclude' => { 'urls' => ['/(/'] } } => 'link_checker.exclude.urls must be a regular expression'
    }.each do |raw, message|
      expect { config(raw) }.to raise_error(Jekyll::Errors::InvalidConfigurationError, /\A#{Regexp.escape(message)}/)
    end
  end

  it 'fails on every dead link, on none with LINK_CHECKER_FAIL=0, and on new ones with LINK_CHECKER_FAIL=new' do
    { nil => :all, '1' => :all, 'yes' => :all, '0' => :none, 'Off' => :none, 'new' => :new, ' NEW ' => :new }
      .each do |value, fail_on|
        with_env('LINK_CHECKER_FAIL' => value) { expect(config(nil).fail_on).to eq(fail_on) }
      end
  end

  it 'reads the baseline and dead links files relative to the site source' do
    with_env('LINK_CHECKER_BASELINE' => 'base.json', 'LINK_CHECKER_DEAD_LINKS' => ' ') do
      expect(config(nil).baseline_file('/site')).to eq('/site/base.json')
      expect(config(nil).dead_links_file('/site')).to be_nil
    end
  end

  it 'reads durations' do
    expect(Jekyll::RubyLinkChecker::Values.duration(90, 'ttl')).to eq(90)
    expect(Jekyll::RubyLinkChecker::Values.duration('45', 'ttl')).to eq(45)
    expect(Jekyll::RubyLinkChecker::Values.duration('2w', 'ttl')).to eq(2 * 604_800)
    expect(Jekyll::RubyLinkChecker::Values.duration(' 30 d ', 'ttl')).to eq(30 * 86_400)
  end

  it 'rejects invalid durations' do
    ['1y', '0', 0, -5, '', nil].each do |value|
      expect { Jekyll::RubyLinkChecker::Values.duration(value, 'cache.ttl') }
        .to raise_error(Jekyll::Errors::InvalidConfigurationError, /link_checker.cache.ttl must be a positive/)
    end
  end

  it 'rejects unknown options with the valid ones' do
    expect { config('excludes' => {}) }.to raise_error(
      Jekyll::Errors::InvalidConfigurationError,
      'Unknown link_checker option: excludes. Valid options: cache, exclude, check, layouts, concurrency, retries, ' \
      'user_agent, verbose, permanent_redirects, blocked, detect_challenges, timeout, connect_timeout, ' \
      'host_concurrency, host_interval, headers, host_headers'
    )
  end

  it 'rejects unknown section options with the valid ones' do
    expect { config('cache' => { 'path' => 'x' }) }.to raise_error(
      Jekyll::Errors::InvalidConfigurationError,
      'Unknown link_checker.cache option: path. Valid options: file, ttl, blocked_ttl, prune'
    )
  end

  it 'rejects options of the wrong type' do
    [
      [{ 'link_checker' => true }],
      { 'cache' => 'file.json' },
      { 'exclude' => { 'domains' => 'example.com' } },
      { 'exclude' => { 'paths' => ['('] } },
      { 'exclude' => { 'urls' => ['/(/'] } },
      { 'concurrency' => 0 },
      { 'concurrency' => '5' },
      { 'retries' => -1 },
      { 'cache' => { 'blocked_ttl' => 0 } },
      { 'cache' => { 'prune' => 'yes' } },
      { 'permanent_redirects' => 'yes' },
      { 'layouts' => 'no' }
    ].each do |raw|
      expect { config(raw) }.to raise_error(Jekyll::Errors::InvalidConfigurationError, /link_checker/)
    end
  end
end
