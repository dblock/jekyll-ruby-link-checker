# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::InternalLinks do
  let(:dir) { Dir.mktmpdir }
  let(:links) { described_class.new(dir, localize: ->(url) { url.sub('https://www.example.com', '') }) }

  after { FileUtils.rm_rf(dir) }

  def write(path, content)
    file = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
  end

  def redirect(to)
    "<html><head><title>Redirecting&hellip;</title></head><body><a href=\"#{to}\">Click here</a></body></html>"
  end

  it 'finds directory indexes and files' do
    write('about/index.html', '<h1 id="team">Team</h1>')
    write('feed.xml', '<feed/>')
    write('a b/index.html', '')
    write('contact.html', '')

    expect(links.check('/about/')).to be_nil
    expect(links.check('/about')).to be_nil
    expect(links.check('/about/index.html')).to be_nil
    expect(links.check('/feed.xml')).to be_nil
    expect(links.check('/a%20b/')).to be_nil
    expect(links.check('/contact')).to be_nil
    expect(links.check('/contact/')).to be_nil
    expect(links.check('/missing/')).to eq('page not found')
  end

  it 'checks anchors by id or name' do
    write('index.html', "<h2 id=\"usage\">Usage</h2><a name='old'></a><p id=\"café\"></p>")

    expect(links.check('/#usage')).to be_nil
    expect(links.check('/#usage')).to be_nil
    expect(links.check('/#old')).to be_nil
    expect(links.check('/#caf%C3%A9')).to be_nil
    expect(links.check('/#')).to be_nil
    expect(links.check('/#missing')).to eq('anchor #missing not found')
  end

  it 'follows redirects, including absolute links to the site, and keeps the anchor' do
    write('old/index.html', redirect('https://www.example.com/new/'))
    write('new/index.html', '<h2 id="usage">Usage</h2>')

    expect(links.check('/old/')).to be_nil
    expect(links.check('/old/#usage')).to be_nil
    expect(links.check('/old/#missing')).to eq('anchor #missing not found')
  end

  it 'reports redirects to missing pages' do
    write('old/index.html', redirect('/gone/'))

    expect(links.check('/old/')).to eq('page not found')
  end

  it 'leaves redirects to other sites, unfollowable redirects, and redirect loops unchecked' do
    write('away/index.html', redirect('https://elsewhere.example.org/'))
    write('broken/index.html', '<title>Redirecting</title>')
    write('loop/index.html', redirect('/loop/'))

    expect(links.check('/away/')).to be_nil
    expect(links.check('/broken/')).to be_nil
    expect(links.check('/loop/')).to be_nil
  end
end
