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

  it 'skips URLs that match a regular expression in exclude.urls, and matches other strings exactly' do
    stub_url('https://github.com/issues', 404)
    stub_url('https://example.org/x', 404)
    links = '[A](https://github.com/issues?q=is%3Aopen) [B](https://github.com/pulls?q=is%3Apr) ' \
            '[C](https://github.com/issues) [D](https://example.org/x)'
    urls = ['/\Ahttps:\/\/github\.com\/(issues|pulls)\?/', '^https://example.org/x']

    expect { build({ 'index.md' => page(links) }, link_checker: { 'exclude' => { 'urls' => urls } }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError,
                      %r{\AFound 2 dead links:\nhttps://example.org/x .*\nhttps://github.com/issues })
  end

  it 'matches exclude.paths against the full URLs of external links' do
    links = '[A](https://github.com/issues?q=is%3Aopen) [B](/tags/ruby/)'
    paths = ['^/tags/', '^https://github\.com/issues']

    expect { build({ 'index.md' => page(links) }, link_checker: { 'exclude' => { 'paths' => paths } }) }
      .not_to raise_error
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

  it 'reuses unverified checks for cache.blocked_ttl' do
    stub_url('https://walled.example.org/', 403)
    allow(Jekyll.logger).to receive(:warn)
    files = { 'index.md' => page('[A](https://walled.example.org/)') }
    cache = { 'file' => '.cache/links.json', 'blocked_ttl' => '1d' }

    build(files, link_checker: { 'cache' => cache })
    Typhoeus::Expectation.clear
    stub_url('https://walled.example.org/', 404)

    expect { build(files, link_checker: { 'cache' => cache }) }.not_to raise_error
    expect { build(files, link_checker: { 'cache' => cache.except('blocked_ttl') }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, /HTTP 404/)
  end

  context 'with cache.prune' do
    let(:cache) { File.join(dir, 'source', '.cache', 'links.json') }
    let(:both) { { 'index.md' => page('[A](https://a.example.org/) [B](https://b.example.org/)') } }
    let(:one) { { 'index.md' => page('[A](https://a.example.org/)') } }

    before do
      stub_url('https://a.example.org/', 200)
      stub_url('https://b.example.org/', 200)
    end

    def entries = JSON.parse(File.read(cache))['entries'].size

    def build_cached(files, prune:, env: { 'LINK_CHECKER' => '1' })
      build(files, link_checker: { 'cache' => { 'file' => '.cache/links.json', 'prune' => prune } }, env: env)
    end

    it 'removes the entries of links that are no longer checked' do
      build_cached(both, prune: true)
      expect(entries).to eq(2)

      build_cached(one, prune: false)
      expect(entries).to eq(2)

      build_cached(one, prune: true)
      expect(entries).to eq(1)
    end

    it 'keeps entries when only changed pages are checked' do
      build_cached(both, prune: true)
      changed = File.join(dir, 'changed.txt')
      File.write(changed, "other.md\n")

      env = { 'LINK_CHECKER' => '1', 'LINK_CHECKER_CHANGED_FILES' => changed }
      build_cached(one.merge('other.md' => page('Other')), prune: true, env: env)
      expect(entries).to eq(2)
    end
  end

  it 'uses LINK_CHECKER_CACHE instead of the configured cache file' do
    stub_url('https://ok.example.org/', 200)
    cache = File.join(dir, 'ci-cache.json')

    build({ 'index.md' => page('[OK](https://ok.example.org/)') },
          env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_CACHE' => cache })

    expect(File).to exist(cache)
  end

  it 'writes a Markdown report of dead links to LINK_CHECKER_REPORT' do
    report = File.join(dir, 'reports', 'links.md')

    expect do
      build({ 'index.md' => page('[Missing](/missing/) <a href="https://dead.example.org/a|b">Dead</a>') },
            env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)

    expect(File.read(report)).to eq(<<~MARKDOWN)
      <!-- jekyll-ruby-link-checker dead links: 2 -->

      Checked 1 internal and 1 external links (0 cached), skipped 0.

      ### 2 Dead Links

      - [/missing/](<https://www.example.com/missing/>) (page not found)
        - [index.md](<https://www.example.com/>)
      - [dead.example.org/a\\|b](<https://dead.example.org/a|b>) (Invalid URL)
        - [index.md](<https://www.example.com/>)

      See [how to fix these links](https://github.com/dblock/jekyll-ruby-link-checker/blob/master/docs/fixing-links.md).
    MARKDOWN
  end

  it 'lists pages by title, collapses long lists, and shortens long links in the report' do
    report = File.join(dir, 'links.md')
    long = "https://dead.example.org/#{'x' * 80}"
    stub_url(long, 404)
    files = {
      'index.md' => page("[A](#{long})", 'title' => 'Home'),
      'b.md' => page("[A](#{long})", 'title' => 'Beta *post*'),
      'c.md' => page("[A](#{long})", 'title' => 'Gamma'),
      'd.md' => page("[A](#{long})", 'title' => 'Delta'),
      'e.md' => page("[A](#{long})")
    }

    expect { build(files, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)
    expect(File.read(report)).to end_with(<<~MARKDOWN)
      - [dead.example.org/#{'x' * 42}…](<#{long}>) (HTTP 404)
        - [Beta \\*post\\*](<https://www.example.com/b.html>)
        - [Delta](<https://www.example.com/d.html>)
        - [e.md](<https://www.example.com/e.html>)
        - <details><summary>2 more pages</summary>

          - [Gamma](<https://www.example.com/c.html>)
          - [Home](<https://www.example.com/>)

          </details>

      See [how to fix these links](https://github.com/dblock/jekyll-ruby-link-checker/blob/master/docs/fixing-links.md).
    MARKDOWN
  end

  it 'lists pages and site paths without links when the site has no URL' do
    report = File.join(dir, 'links.md')

    expect do
      build({ 'index.md' => page('[Missing](/missing/)', 'title' => 'Home') },
            config: { 'url' => nil }, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)
    expect(File.read(report)).to include("- /missing/ (page not found)\n  - Home\n")
  end

  it 'reports dead links without failing the build when LINK_CHECKER_FAIL is off' do
    report = File.join(dir, 'links.md')
    files = { 'index.md' => page('[Missing](/missing/)') }

    allow(Jekyll.logger).to receive(:warn)
    %w[0 false No OFF].each do |value|
      env = { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report, 'LINK_CHECKER_FAIL' => value }
      expect { build(files, env: env) }.not_to raise_error
      expect(File.read(report)).to start_with('<!-- jekyll-ruby-link-checker dead links: 1 -->')
    end
    expect(Jekyll.logger).to have_received(:warn)
      .with('LinkChecker:', "Found 1 dead link:\n/missing/ (page not found), linked from index.md").exactly(4).times

    %w[1 true].each do |value|
      expect { build(files, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_FAIL' => value }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)
    end
  end

  it 'writes a report without dead links, and none unless LINK_CHECKER_REPORT is set' do
    report = File.join(dir, 'links.md')
    files = { 'index.md' => page('[About](/about/)'), 'about.md' => about }

    build(files)
    expect(File).not_to exist(report)

    build(files, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    expect(File.read(report)).to eq(
      "<!-- jekyll-ruby-link-checker dead links: 0 -->\n\n" \
      "Checked 1 internal and 0 external links (0 cached), skipped 0.\n\nNo dead links.\n"
    )
  end

  context 'with links blocked by bot protection' do
    let(:report) { File.join(dir, 'links.md') }

    before do
      stub_url('https://walled.example.org/', 403)
      stub_url('https://linkedin.example.org/', 999)
      Typhoeus.stub('https://challenge.example.org/').and_return(
        Typhoeus::Response.new(code: 503, headers: { 'cf-mitigated' => 'challenge' }, body: '')
      )
      allow(Jekyll.logger).to receive(:warn)
    end

    def build_blocked
      build({ 'index.md' => page('[A](https://walled.example.org/) [B](https://linkedin.example.org/) ' \
                                 '[C](https://challenge.example.org/)') },
            env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    end

    it 'warns that they are unverified without failing the build' do
      expect { build_blocked }.not_to raise_error

      expect(Jekyll.logger).to have_received(:warn).with(
        'LinkChecker:',
        "Couldn't verify 3 links, which bot protection blocked:\n" \
        "https://challenge.example.org/ (Cloudflare challenge (HTTP 503)), linked from index.md\n" \
        "https://linkedin.example.org/ (HTTP 999), linked from index.md\n" \
        'https://walled.example.org/ (HTTP 403), linked from index.md'
      )
    end

    it 'lists them in the report' do
      build_blocked

      expect(File.read(report)).to start_with(<<~MARKDOWN)
        <!-- jekyll-ruby-link-checker dead links: 0 -->

        Checked 0 internal and 3 external links (0 cached), skipped 0. Couldn't verify 3 links.

        No dead links.

        ### 3 Unverified Links

        Bot protection blocked these checks, so these links may work. Check them in a browser.

        <details><summary>3 sites</summary>

        - challenge.example.org: 1 link, Cloudflare challenge (HTTP 503)
          - [challenge.example.org/](<https://challenge.example.org/>)
        - linkedin.example.org: 1 link, HTTP 999
          - [linkedin.example.org/](<https://linkedin.example.org/>)
        - walled.example.org: 1 link, HTTP 403
          - [walled.example.org/](<https://walled.example.org/>)

        </details>
      MARKDOWN
    end

    it 'suggests excluding sites with several unverified links, other unverified links, and sites that failed' do
      stub_url('https://walled.example.org/a', 403)
      stub_url('https://walled.example.org/b', 401)
      stub_url('https://broken.example.org/', 500)
      stub_url('https://gone.example.org/', 404)
      stub_url("https://x.example.org/it's", 999)
      links = '[A](https://walled.example.org/a) [B](https://walled.example.org/b) ' \
              '[C](https://linkedin.example.org/) ' \
              '[D](https://broken.example.org/) [E](https://gone.example.org/) [F](/missing/) ' \
              "[G](https://x.example.org/it's)"
      expect { build({ 'index.md' => page(links) }, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)

      yaml = File.read(report)[/```yaml\n(.*?)```/m, 1]
      expect(yaml).to eq(<<~YAML)
        link_checker:
          exclude:
            domains:
              - walled.example.org # 2 unverified links
            urls:
              - 'https://broken.example.org/' # HTTP 500
              - 'https://linkedin.example.org/' # HTTP 999
              - 'https://x.example.org/it''s' # HTTP 999
      YAML
      excluded = Jekyll::RubyLinkChecker::Configuration.new(YAML.safe_load(yaml)['link_checker']).exclude
      expect(excluded.urls).to include("https://x.example.org/it's")
    end

    it 'groups them by site, with the most links first, and lists the reasons of each site' do
      stub_url('https://walled.example.org/a', 403)
      stub_url('https://walled.example.org/b', 401)
      build({ 'index.md' => page('[A](https://walled.example.org/a) [B](https://walled.example.org/b) ' \
                                 '[C](https://linkedin.example.org/)') },
            env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })

      expect(File.read(report)).to include(<<~MARKDOWN)
        <details><summary>2 sites</summary>

        - walled.example.org: 2 links, HTTP 401, HTTP 403
          - [walled.example.org/a](<https://walled.example.org/a>)
          - [walled.example.org/b](<https://walled.example.org/b>)
        - linkedin.example.org: 1 link, HTTP 999
      MARKDOWN
    end
  end

  it 'fails only on dead links when others are unverified' do
    stub_url('https://walled.example.org/', 403)
    stub_url('https://dead.example.org/', 404)
    allow(Jekyll.logger).to receive(:warn)

    expect { build({ 'index.md' => page('[A](https://walled.example.org/) [B](https://dead.example.org/)') }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError,
                      %r{\AFound 1 dead link:\nhttps://dead.example.org/ \(HTTP 404\), linked from index.md\z})
    expect(Jekyll.logger).to have_received(:warn).with('LinkChecker:', /\ACouldn't verify 1 link, /)
  end

  it 'follows redirects to the final result' do
    Typhoeus.stub('https://moved.example.org/').and_return(
      Typhoeus::Response.new(code: 301, headers: { 'Location' => 'https://new.example.org/' }, body: '')
    )
    Typhoeus.stub('https://gone.example.org/').and_return(
      Typhoeus::Response.new(code: 302, headers: { 'Location' => 'https://dead.example.org/' }, body: '')
    )
    stub_url('https://new.example.org/', 200)
    stub_url('https://dead.example.org/', 404)

    expect { build({ 'index.md' => page('[Moved](https://moved.example.org/) [Gone](https://gone.example.org/)') }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError,
                      %r{\AFound 1 dead link:\nhttps://gone.example.org/ \(HTTP 404\), linked from index.md\z})
  end

  context 'with links that redirect' do
    let(:report) { File.join(dir, 'links.md') }
    let(:files) { { 'index.md' => page('[Moved](https://moved.example.org/) [Temp](https://temp.example.org/)') } }

    before do
      Typhoeus.stub('https://moved.example.org/').and_return(
        Typhoeus::Response.new(code: 301, headers: { 'Location' => 'https://new.example.org/' }, body: '')
      )
      Typhoeus.stub('https://temp.example.org/').and_return(
        Typhoeus::Response.new(code: 302, headers: { 'Location' => 'https://new.example.org/' }, body: '')
      )
      stub_url('https://new.example.org/', 200)
      allow(Jekyll.logger).to receive(:warn)
    end

    def build_redirects(link_checker)
      build(files, link_checker: link_checker, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    end

    it 'reports links that moved permanently with permanent_redirects' do
      expect { build_redirects('permanent_redirects' => true) }.not_to raise_error

      expect(Jekyll.logger).to have_received(:warn).with(
        'LinkChecker:',
        "1 link moved permanently:\nhttps://moved.example.org/ to https://new.example.org/, linked from index.md"
      )
      expect(File.read(report)).to end_with(<<~MARKDOWN)
        Checked 0 internal and 2 external links (0 cached), skipped 0. 1 link moved permanently.

        No dead links.

        ### 1 Link Moved Permanently

        These links work, but redirect permanently. Update them to link to where they moved.

        - [moved.example.org/](<https://moved.example.org/>) moved to [new.example.org/](<https://new.example.org/>)
          - [index.md](<https://www.example.com/>)

        See [how to fix these links](https://github.com/dblock/jekyll-ruby-link-checker/blob/master/docs/fixing-links.md).
      MARKDOWN
    end

    it 'reports them from the cache' do
      cache = { 'file' => '.cache/links.json' }
      build_redirects('cache' => cache)
      build_redirects('cache' => cache, 'permanent_redirects' => true)

      expect(File.read(report)).to include('(2 cached), skipped 0. 1 link moved permanently.')
    end

    it 'does not report them by default' do
      build_redirects({})

      expect(Jekyll.logger).not_to have_received(:warn).with('LinkChecker:', /moved permanently/)
      expect(File.read(report)).not_to include('Moved Permanently')
    end
  end

  it 'falls back to GET when HEAD fails' do
    Typhoeus.stub('https://nohead.example.org/') do |request|
      Typhoeus::Response.new(code: request.options[:method] == :head ? 405 : 200, body: '')
    end

    expect { build({ 'index.md' => page('[No HEAD](https://nohead.example.org/)') }) }.not_to raise_error
  end

  context 'with images' do
    let(:png) { 'not really a png' }

    it 'checks local images, every candidate of srcset, and picture sources' do
      html = '<img src="/images/a.png"> <img src="/images/missing.png"> ' \
             '<img srcset="/images/a.png 1x, /images/missing-2x.png 2x" src="/images/a.png"> ' \
             '<picture><source srcset="/images/missing.webp" type="image/webp"><img src="b.png"></picture>'
      files = { 'images/a.png' => png, 'posts/b.png' => png, 'posts/index.html' => page(html) }

      expect { build(files) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
        expect(error.message).to eq(
          "Found 3 dead links:\n" \
          "/images/missing-2x.png (image not found), linked from posts/index.html\n" \
          "/images/missing.png (image not found), linked from posts/index.html\n" \
          '/images/missing.webp (image not found), linked from posts/index.html'
        )
      }
    end

    it 'removes tabs and newlines from URLs, as browsers do' do
      html = "<img src=\"/images/\na.png\"> <a href=\"/images/a\t.png\">A</a> <img srcset=\"/images/a.png\n2x\">"
      files = { 'images/a.png' => png, 'index.html' => page(html) }

      expect { build(files) }.not_to raise_error
    end

    it 'skips data URIs and lazy-loading attributes, and applies exclusions to images' do
      html = '<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" data-src="/images/lazy.png"> ' \
             '<img src="/assets/missing.png">'

      expect { build({ 'index.html' => page(html) }, link_checker: { 'exclude' => { 'paths' => ['^/assets/'] } }) }
        .not_to raise_error
    end

    it 'checks external images and says they are images' do
      stub_url('https://cdn.example.org/gone.png', 404)
      stub_url('https://cdn.example.org/ok.png', 200)
      html = '<img src="https://cdn.example.org/gone.png"> <img src="//cdn.example.org/ok.png">'

      expect { build({ 'index.html' => page(html) }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError,
                        %r{\AFound 1 dead link:\nhttps://cdn.example.org/gone.png \(image: HTTP 404\), linked from})
    end

    it 'only checks images on the site with images: { external: false }' do
      html = '<img src="https://cdn.example.org/a.png"> <img src="/images/missing.png">'
      report = File.join(dir, 'links.md')

      expect do
        build({ 'index.html' => page(html) }, link_checker: { 'check' => { 'images' => { 'external' => false } } },
                                              env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
      end.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 1 dead link:\n/images/missing.png })
      expect(File.read(report)).to include('Checked 1 internal and 0 external links (0 cached), skipped 1.')
    end

    it 'finds images where tags say, such as lazy-loaded ones, and unquoted attributes and area links' do
      html = '<img data-src="/images/lazy.png" src=/images/a.png> <a data-href="/nowhere/">A</a> ' \
             '<map><area href="/missing-area/"></map>'
      files = { 'images/a.png' => png, 'index.html' => page(html) }
      images = { 'tags' => { 'img' => %w[src data-src] } }

      expect { build(files, link_checker: { 'check' => { 'images' => images } }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
          expect(error.message).to eq(
            "Found 2 dead links:\n/images/lazy.png (image not found), linked from index.html\n" \
            '/missing-area/ (page not found), linked from index.html'
          )
        }
    end

    it 'does not check images with check.images: false' do
      html = '<img src="/images/missing.png">'

      expect { build({ 'index.html' => page(html) }, link_checker: { 'check' => { 'images' => false } }) }
        .not_to raise_error
    end
  end

  context 'with options of a kind' do
    let(:report) { File.join(dir, 'links.md') }
    let(:html) do
      '<img src="/images/missing.png"> <img src="https://cdn.example.org/gone.png"> <a href="/missing/">M</a> ' \
        '<a href="#nowhere">N</a> <a href="/about/#nowhere">A</a>'
    end
    let(:files) { { 'index.html' => page(html), 'about.html' => page('About') } }

    before { stub_url('https://cdn.example.org/gone.png', 404) }

    def build_report(check)
      build(files, link_checker: { 'check' => check }, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report })
    end

    it 'lists dead references of a kind with fail: false as warnings, and only fails on the others' do
      expect { build_report('images' => { 'fail' => false }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 3 dead links:\n/#nowhere })
      expect(File.read(report)).to include(
        "<!-- jekyll-ruby-link-checker dead links: 3 -->\n\nChecked 3 internal and 1 external links (0 cached), " \
        "skipped 0. 2 warnings.\n",
        "### 2 Warnings\n\nThese links are dead, but are set not to fail the build, with `fail: false`.\n\n" \
        "- [/images/missing.png](<https://www.example.com/images/missing.png>) (image not found)\n  " \
        "- [index.html](<https://www.example.com/>)\n" \
        "- [cdn.example.org/gone.png](<https://cdn.example.org/gone.png>) (image: HTTP 404)\n"
      )
    end

    it 'passes when every kind with dead references has fail: false' do
      expect { build_report('defaults' => { 'fail' => false }) }.not_to raise_error
      expect(File.read(report)).to include('### 5 Warnings')
    end

    it 'skips anchors with links: { anchors: false }' do
      expect { build_report('links' => { 'anchors' => false }, 'images' => false) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 1 dead link:\n/missing/ })
    end

    it 'adds the exclusions of a kind, and of every kind, to the others' do
      check = { 'defaults' => { 'exclude' => { 'domains' => ['cdn.example.org'] } },
                'images' => { 'exclude' => { 'paths' => ['^/images/'] } },
                'links' => { 'anchors' => false } }

      expect { build_report(check) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
        expect(error.message).to eq("Found 1 dead link:\n/missing/ (page not found), linked from index.html")
      }
      expect(File.read(report)).to include('skipped 2.')
    end

    it 'does not exclude links with the exclusions of images' do
      check = { 'images' => { 'exclude' => { 'paths' => ['^/missing/'] } }, 'links' => { 'anchors' => false } }

      expect { build_report(check) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, /\AFound 3 dead links/)
    end
  end

  context 'with scripts and stylesheets' do
    let(:html) do
      '<link rel="stylesheet" href="/css/missing.css"> <link rel="alternate stylesheet" href="/css/dark.css"> ' \
        '<link rel="icon" href="/missing.ico"> <link rel="preconnect" href="https://fonts.example.org"> ' \
        '<link href="/css/site.css" rel="stylesheet"> <script src="/js/missing.js" defer></script> ' \
        '<script>console.log("inline")</script> <script src="/js/site.js"></script>'
    end
    let(:files) { { 'css/site.css' => '', 'js/site.js' => '', 'index.html' => page(html) } }

    it 'checks scripts, stylesheets, and other link tags, but not connections to origins' do
      expect { build(files) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
        expect(error.message).to eq(
          "Found 4 dead links:\n" \
          "/css/dark.css (stylesheet not found), linked from index.html\n" \
          "/css/missing.css (stylesheet not found), linked from index.html\n" \
          "/js/missing.js (script not found), linked from index.html\n" \
          '/missing.ico (page not found), linked from index.html'
        )
      }
    end

    it 'does not check scripts and stylesheets when they are turned off' do
      check = { 'scripts' => false, 'stylesheets' => false }

      expect { build(files, link_checker: { 'check' => check }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 1 dead link:\n/missing.ico })
    end

    it 'checks external scripts and says they are scripts' do
      stub_url('https://cdn.example.org/gone.js', 404)

      expect { build({ 'index.html' => page('<script src="https://cdn.example.org/gone.js"></script>') }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, /gone.js \(script: HTTP 404\), linked from/)
    end
  end

  context 'with layouts' do
    let(:files) do
      {
        '_layouts/default.html' => '<html><head><link rel="stylesheet" href="/css/missing.css"></head><body><nav>' \
                                   '<a href="/about/">About</a> <a href="/missing-nav/">Missing</a> ' \
                                   '<a href="#top">Top</a></nav>{{ content }}{% include footer.html %}</body></html>',
        '_includes/footer.html' => '<a href="/missing-footer/">Footer</a>',
        'index.md' => "---\nlayout: default\ntitle: Home\n---\n[About](/about/) [Gone](/gone/)\n",
        'about.md' => "---\nlayout: default\ntitle: About\npermalink: /about/\n---\nAbout us.\n"
      }
    end

    it 'reports what layouts and includes reference once, from the layout, and the rest from the page' do
      expect { build(files) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError) { |error|
        expect(error.message).to eq(
          "Found 5 dead links:\n" \
          "#top (anchor not found), linked from _layouts/default.html\n" \
          "/css/missing.css (stylesheet not found), linked from _layouts/default.html\n" \
          "/gone/ (page not found), linked from index.md\n" \
          "/missing-footer/ (page not found), linked from _layouts/default.html\n" \
          '/missing-nav/ (page not found), linked from _layouts/default.html'
        )
      }
    end

    it 'lists the layout without a link in the report' do
      report = File.join(dir, 'links.md')
      expect { build(files, env: { 'LINK_CHECKER' => '1', 'LINK_CHECKER_REPORT' => report }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError)

      expect(File.read(report))
        .to include("- [/missing-nav/](<https://www.example.com/missing-nav/>) (page not found)\n  " \
                    "- \\_layouts/default.html\n")
    end

    it 'only checks the content with layouts: false' do
      expect { build(files, link_checker: { 'layouts' => false }) }
        .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 1 dead link:\n/gone/ })
    end
  end

  it 'reports links blocked by bot protection as dead with blocked: false' do
    stub_url('https://walled.example.org/', 403)

    expect { build({ 'index.md' => page('[A](https://walled.example.org/)') }, link_checker: { 'blocked' => false }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{https://walled.example.org/ \(HTTP 403\)})
  end

  it 'reports challenges as dead with detect_challenges: false' do
    Typhoeus.stub('https://challenge.example.org/').and_return(
      Typhoeus::Response.new(code: 503, headers: { 'cf-mitigated' => 'challenge' }, body: '')
    )

    files = { 'index.md' => page('[A](https://challenge.example.org/)') }

    expect { build(files, link_checker: { 'detect_challenges' => false }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, /Cloudflare challenge \(HTTP 503\)/)
  end

  it 'sends host headers only to their hosts' do
    %w[https://npm.example.org/ https://other.example.org/ https://www.medium.example.org/].each do |url|
      Typhoeus.stub(url) do |request|
        headers = request.options[:headers]
        Typhoeus::Response.new(code: headers['Accept'] == 'text/html' || headers['X'] == 'y' ? 200 : 404)
      end
    end
    links = '[A](https://npm.example.org/) [B](https://other.example.org/) [C](https://www.medium.example.org/)'
    host_headers = { 'npm.example.org' => { 'Accept' => 'text/html' }, '/medium\.example\.org\z/' => { 'X' => 'y' } }

    expect { build({ 'index.md' => page(links) }, link_checker: { 'host_headers' => host_headers }) }
      .to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, %r{\AFound 1 dead link:\nhttps://other.example.org/ })
  end

  it 'passes request options to ruby-link-checker' do
    allow(LinkChecker::Typhoeus::Hydra::Checker).to receive(:new).and_call_original

    build({ 'index.md' => page('[About](/about/)'), 'about.md' => about },
          link_checker: { 'timeout' => '30s', 'connect_timeout' => 3, 'host_concurrency' => 2, 'host_interval' => 0.1 })

    expect(LinkChecker::Typhoeus::Hydra::Checker).to have_received(:new).with(
      hash_including(timeout: 30, connecttimeout: 3, max_concurrency_per_host: 2, min_host_interval: 0.1)
    )
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
