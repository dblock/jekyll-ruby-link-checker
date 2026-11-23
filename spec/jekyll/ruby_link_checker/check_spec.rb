# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Check do
  def kinds(raw)
    described_class.new(raw).kinds.to_h { |kind| [kind.name, kind] }
  end

  def error(raw)
    described_class.new(raw)
  rescue Jekyll::Errors::InvalidConfigurationError => e
    e.message
  end

  it 'checks every kind, inside and outside the site, by default' do
    expect(kinds(nil).values.map(&:name)).to eq(%w[links images scripts stylesheets])
    expect(kinds(nil).values).to all(have_attributes(internal: true, external: true))
    expect(kinds(nil)['images'].label).to eq('image')
  end

  it 'turns kinds off with false, and keeps their defaults with true' do
    expect(kinds('images' => false, 'scripts' => false).keys).to eq(%w[links stylesheets])
    expect(kinds('images' => true).keys).to eq(%w[links images scripts stylesheets])
  end

  it 'applies defaults to every kind that does not set its own' do
    checked = kinds('defaults' => { 'external' => false }, 'links' => { 'external' => true })

    expect(checked['links']).to have_attributes(internal: true, external: true)
    expect(checked['images']).to have_attributes(internal: true, external: false)
  end

  it 'replaces where a kind is found with tags' do
    images = kinds('images' => { 'tags' => { 'img' => %w[data-src SRC] } })['images']

    attributes = { 'data-src' => '/a.png', 'src' => '/b.png', 'srcset' => '/c.png 2x' }
    expect(images.urls('img', attributes)).to eq(%w[/a.png /b.png])
  end

  it 'rejects unknown kinds and options, and invalid values, naming them' do
    {
      'yes' => 'link_checker.check must be a set of options',
      { 'videos' => true } =>
        'Unknown link_checker.check option: videos. Valid options: defaults, links, images, scripts, stylesheets',
      { 'images' => { 'fetch' => true } } =>
        'Unknown link_checker.check.images option: fetch. Valid options: tags, internal, external',
      { 'defaults' => { 'tags' => {} } } => 'Unknown link_checker.check.defaults option: tags.',
      { 'images' => 'no' } => 'link_checker.check.images must be true, false, or a set of options',
      { 'images' => { 'external' => 'no' } } => 'link_checker.check.images.external must be true or false',
      { 'images' => { 'tags' => [] } } => 'link_checker.check.images.tags must be a set of selectors',
      { 'images' => { 'tags' => { 'img[' => 'src' } } } => 'link_checker.check.images.tags must be a selector',
      { 'images' => { 'tags' => { 'img' => ['', 'src'] } } } =>
        'link_checker.check.images.tags.img must be a list of attribute names'
    }.each { |raw, message| expect(error(raw)).to start_with(message) }
  end
end
