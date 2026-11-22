# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Checker do
  let(:dir) { Dir.mktmpdir }
  let(:about) { page('<h2 id="team">Team</h2>') }

  after { FileUtils.rm_rf(dir) }

  def build(files, **options)
    build_site(dir, files, **options)
  end

  it 'passes when internal links, anchors, and external links work' do
    stub_url('https://ok.example.org/', 200)

    expect do
      build(
        {
          'index.md' => page('[About](/about/) [Team](/about/#team) [Self](https://www.example.com/about/) ' \
                             '[Here](#top) [OK](https://ok.example.org/) [Scheme-relative](//ok.example.org/) ' \
                             '[Home](https://www.example.com)' \
                             "\n\n<h1 id=\"top\">Top</h1>"),
          'about.md' => about
        }
      )
    end.not_to raise_error
  end

  it 'fails listing dead internal links, missing anchors, and where they are linked from' do
    expect do
      build(
        {
          'index.md' => page('[Missing](/missing/) [Gone](/about/#gone) [Here](#nowhere)'),
          'other.md' => page('[Missing](/missing/)'),
          'about.md' => about
        }
      )
    end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
      expect(error.message).to start_with('Found 3 dead links:')
      expect(error.message).to include('/missing/ (page not found), linked from index.md, other.md')
      expect(error.message).to include('/about/#gone (anchor #gone not found), linked from index.md')
      expect(error.message).to include('/#nowhere (anchor not found), linked from index.md')
    }
  end

  it 'fails on dead external links with the HTTP status' do
    stub_url('https://dead.example.org/', 404)

    expect { build({ 'index.md' => page('[Dead](https://dead.example.org/)') }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError,
                      %r{Found 1 dead link:\nhttps://dead.example.org/ \(HTTP 404\), linked from index.md})
  end

  it 'skips excluded domains and their subdomains, URLs, paths, and other schemes without requesting them' do
    expect do
      build(
        {
          'index.md' => page('[A](https://excluded.example.org/) [B](https://www.excluded.example.org/x) ' \
                             '[C](https://flaky.example.net/page) [D](/tags/ruby/) [E](mailto:me@example.com) ' \
                             '[F](tel:+15555555555)')
        },
        link_checker: {
          'exclude' => {
            'domains' => ['excluded.example.org'],
            'urls' => ['https://flaky.example.net/page'],
            'paths' => ['^/tags/']
          }
        }
      )
    end.not_to raise_error
  end

  it 'skips pages that opt out and outputs that are not HTML' do
    expect do
      build(
        {
          'index.md' => page('[Missing](/missing/)', 'link_checker' => false),
          'feed.xml' => page('<a href="/missing/">Missing</a>')
        }
      )
    end.not_to raise_error
  end

  it 'does nothing unless LINK_CHECKER is set' do
    files = { 'index.md' => page('[Missing](/missing/)') }

    expect { build(files, env: {}) }.not_to raise_error
    expect { build(files, env: { 'LINK_CHECKER' => 'false' }) }.not_to raise_error
    expect { build(files, env: { 'LINK_CHECKER' => '0' }) }.not_to raise_error
  end

  it 'logs a summary, and each link only when verbose' do
    stub_url('https://ok.example.org/', 200)
    files = { 'index.md' => page('[About](/about/) [OK](https://ok.example.org/) [Mail](mailto:me@example.com)'),
              'about.md' => about }
    messages = []
    allow(Jekyll.logger).to receive(:info).and_wrap_original do |original, topic, message = nil|
      messages << "#{topic} #{message}"
      original.call(topic, message)
    end

    build(files)
    expect(messages).to include('LinkChecker: Checked 1 internal and 1 external links (0 cached), skipped 1.')
    expect(messages.grep(/ok.example.org/)).to be_empty

    messages.clear
    build(files, link_checker: { 'verbose' => true })
    expect(messages).to include('LinkChecker: /about/: OK', 'LinkChecker: https://ok.example.org/: OK')
  end

  it 'reuses successful checks from the cache file and never caches failures' do
    stub_url('https://ok.example.org/', 200)
    stub_url('https://dead.example.org/', 404)
    files = { 'index.md' => page('[OK](https://ok.example.org/)') }
    options = { link_checker: { 'cache' => { 'file' => '.cache/links.json', 'ttl' => '1d' } } }

    build(files, **options)
    cache = File.join(dir, 'source', '.cache', 'links.json')
    expect(JSON.parse(File.read(cache))['entries'].size).to eq(1)

    Typhoeus::Expectation.clear
    stub_url('https://ok.example.org/', 500)
    stub_url('https://dead.example.org/', 404)
    messages = []
    allow(Jekyll.logger).to receive(:info).and_wrap_original do |original, topic, message = nil|
      messages << "#{topic} #{message}"
      original.call(topic, message)
    end
    expect { build(files, **options) }.not_to raise_error
    expect(messages).to include('LinkChecker: Checked 0 internal and 1 external links (1 cached), skipped 0.')

    expect { build({ 'index.md' => page('[Dead](https://dead.example.org/)') }, **options) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)
    expect(JSON.parse(File.read(cache))['entries'].size).to eq(1)
  end

  it 'uses LINK_CHECKER_CACHE instead of the configured cache file' do
    stub_url('https://ok.example.org/', 200)
    cache = File.join(dir, 'ci-cache.json')

    build({ 'index.md' => page('[OK](https://ok.example.org/)') },
          env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_CACHE' => cache })

    expect(File).to exist(cache)
  end

  it 'sends the configured user agent' do
    Typhoeus.stub('https://ok.example.org/') do |request|
      Typhoeus::Response.new(code: request.options[:headers]['User-Agent'] == 'Test Checker' ? 200 : 403)
    end

    expect do
      build({ 'index.md' => page('[OK](https://ok.example.org/)') }, link_checker: { 'user_agent' => 'Test Checker' })
    end.not_to raise_error
  end

  it 'resolves relative links against the page URL' do
    expect do
      build(
        {
          'docs/guide.md' => page('[About](../about/) [Intro](intro.html) [Start](intro.html#start) ' \
                                  '[Missing](missing.html) [Up](../) ' \
                                  '<a href="bad page.html">Bad</a>'),
          'docs/intro.md' => page('<h2 id="start">Start</h2>'),
          'about.md' => about,
          'index.md' => page('Home')
        }
      )
    end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
      expect(error.message).to start_with('Found 2 dead links:')
      expect(error.message).to include('/docs/missing.html (page not found), linked from docs/guide.md')
      expect(error.message).to include('bad page.html (page not found), linked from docs/guide.md')
    }
  end

  it 'checks links to the site itself as internal links when the site has no URL' do
    expect do
      build({ 'index.md' => page('[About](/about/) <a href="">Empty</a> <a href="#">Top</a>'), 'about.md' => about },
            config: { 'url' => nil })
    end.not_to raise_error
  end

  it 'reports external links that are not valid URLs' do
    expect do
      build({ 'index.md' => page('<a href="https://exa mple.org/">Broken</a>') },
            link_checker: { 'exclude' => { 'domains' => ['example.org'] } })
    end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{https://exa mple.org/})
  end

  it 'rejects invalid configuration when the build starts' do
    expect { build({ 'index.md' => page('Hello') }, link_checker: { 'unknown' => true }) }
      .to raise_error(Jekyll::Errors::InvalidConfigurationError, /Unknown link_checker option: unknown/)
  end
end
