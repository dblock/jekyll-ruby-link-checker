# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::ChangedFiles do
  let(:dir) { Dir.mktmpdir }
  let(:changed) { File.join(dir, 'changed.txt') }
  let(:report) { File.join(dir, 'links.md') }
  let(:files) do
    {
      'index.md' => page('[Index](/index-missing/)'),
      'other.md' => page('[Other](/other-missing/)'),
      '_posts/2024-01-01-hello.md' => page('[Post](/post-missing/)'),
      '_layouts/plain.html' => '{{ content }}',
      'assets/logo.png' => 'png'
    }
  end

  after { FileUtils.rm_rf(dir) }

  # Builds the site with `paths` as the changed files and returns the dead links, or none.
  def dead_links(paths, file: changed)
    File.write(changed, paths.join("\n"))
    env = { 'LINK_CHECKER' => '1', 'LINK_CHECKER_CHANGED_FILES' => file, 'LINK_CHECKER_REPORT' => report }
    build_site(dir, files, env: env)
    []
  rescue Jekyll::RubyLinkChecker::DeadLinksError => e
    e.message.lines.drop(1).map { |line| line.split.first }
  end

  it 'checks only changed pages and documents' do
    expect(dead_links(%w[other.md _posts/2024-01-01-hello.md])).to eq(%w[/other-missing/ /post-missing/])
    expect(File.read(report)).to include('Checked 2 internal and 0 external links (0 cached) on 2 changed pages')
  end

  it 'ignores changed static files, blank lines, and leading ./ and /' do
    expect(dead_links(['./assets/logo.png', '', ' /index.md '])).to eq(%w[/index-missing/])
    expect(File.read(report)).to include('on 1 changed page,')
  end

  it 'checks nothing when no page changed' do
    expect(dead_links(%w[assets/logo.png])).to be_empty
    expect(File.read(report)).to include('Checked 0 internal and 0 external links (0 cached) on 0 changed pages')
  end

  it 'checks all pages when a file other than a page or a static file changed' do
    allow(Jekyll.logger).to receive(:info)

    expect(dead_links(%w[other.md _layouts/plain.html _config.yml]))
      .to eq(%w[/index-missing/ /other-missing/ /post-missing/])
    expect(Jekyll.logger).to have_received(:info)
      .with('LinkChecker:', "Checking all pages, because _config.yml and 1 other changed files aren't pages.")
    expect(File.read(report)).not_to include('changed page')
  end

  it 'reads the list from a path relative to the site source' do
    expect(dead_links(%w[other.md], file: '../changed.txt')).to eq(%w[/other-missing/])
  end

  it 'checks all pages without LINK_CHECKER_CHANGED_FILES' do
    expect { build_site(dir, files) }.to raise_error(Jekyll::RubyLinkChecker::DeadLinksError, /Found 3 dead links/)
  end
end
