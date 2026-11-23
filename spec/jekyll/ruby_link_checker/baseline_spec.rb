# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Baseline do
  let(:dir) { Dir.mktmpdir }
  let(:file) { File.join(dir, 'baselines', 'dead-links.json') }

  after { FileUtils.rm_rf(dir) }

  it 'writes dead links, sorted, and reads them back' do
    described_class.write(file, { '/b/' => { reason: 'page not found', locations: Set['z.md', 'a.md'] },
                                  '/a/' => { reason: 'HTTP 404', locations: Set['a.md'] } })

    baseline = described_class.read(file)
    expect(baseline.links.keys).to eq(%w[/a/ /b/])
    expect(baseline.links['/b/']).to eq(reason: 'page not found', locations: Set['a.md', 'z.md'])
    expect(baseline).to include('/a/')
    expect(baseline).not_to include('/c/')
  end

  it 'has no baseline without a file' do
    expect(described_class.read(nil)).to be_nil
    expect(described_class.read(file)).to be_nil
  end

  it 'ignores files that cannot be read, with a warning' do
    allow(Jekyll.logger).to receive(:warn)
    FileUtils.mkdir_p(File.dirname(file))
    ['not json', '[]', '{"version": 1}', '{"version": 1, "dead_links": [{"url": "/a/"}]}',
     '{"version": 1, "dead_links": 1}'].each do |content|
      File.write(file, content)
      expect(described_class.read(file)).to be_nil
    end
    expect(Jekyll.logger).to have_received(:warn).exactly(5).times
  end
end
