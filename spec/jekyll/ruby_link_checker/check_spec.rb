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
    expect(kinds(nil).values.map(&:name)).to eq(%w[links images scripts stylesheets media iframes])
    expect(kinds(nil).values).to all(have_attributes(internal: true, external: true))
    expect(kinds(nil)['images'].label).to eq('image')
  end

  it 'turns kinds off with false, and keeps their defaults with true' do
    expect(kinds('images' => false, 'scripts' => false).keys).to eq(%w[links stylesheets media iframes])
    expect(kinds('images' => true).keys).to eq(%w[links images scripts stylesheets media iframes])
  end

  it 'fails on every kind, checks anchors, and has no exclusions of its own by default' do
    expect(kinds(nil).values).to all(have_attributes(fail: true, anchors: true, exclude: []))
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

  it 'adds kinds of the site, after the built-in ones, labeled by their name' do
    lazy = kinds('lazy_images' => { 'tags' => { 'img' => 'data-src' }, 'external' => false })['lazy_images']

    expect(kinds('lazy_images' => { 'tags' => { 'img' => 'data-src' } }).keys.last).to eq('lazy_images')
    expect(lazy).to have_attributes(label: 'lazy_images', internal: true, external: false, fail: true)
    expect(lazy.urls('img', 'data-src' => '/a.png')).to eq(%w[/a.png])
  end

  it 'rejects unknown kinds and options, and invalid values, naming them' do
    {
      'yes' => 'link_checker.check must be a set of options',
      { 'image' => { 'external' => false } } =>
        "link_checker.check.image must be a kind with tags, as it isn't one of links, images, scripts, stylesheets, " \
        'media, iframes',
      { 'Lazy Images' => { 'tags' => { 'img' => 'data-src' } } } => 'link_checker.check.Lazy Images must be a kind',
      { 'lazy' => true } => 'link_checker.check.lazy must be a kind with tags',
      { 'images' => { 'fetch' => true } } =>
        'Unknown link_checker.check.images option: fetch. Valid options: tags, internal, external, fail, exclude',
      { 'defaults' => { 'tags' => {} } } => 'Unknown link_checker.check.defaults option: tags.',
      { 'images' => 'no' } => 'link_checker.check.images must be true, false, or a set of options',
      { 'images' => { 'external' => 'no' } } => 'link_checker.check.images.external must be true or false',
      { 'images' => { 'tags' => [] } } => 'link_checker.check.images.tags must be a set of selectors',
      { 'images' => { 'tags' => { 'img[' => 'src' } } } => 'link_checker.check.images.tags must be a selector',
      { 'images' => { 'tags' => { 'img' => ['', 'src'] } } } =>
        'link_checker.check.images.tags.img must be a list of attribute names',
      { 'images' => { 'anchors' => false } } => 'Unknown link_checker.check.images option: anchors.',
      { 'links' => { 'anchors' => 'no' } } => 'link_checker.check.links.anchors must be true or false',
      { 'images' => { 'fail' => 'no' } } => 'link_checker.check.images.fail must be true or false',
      { 'images' => { 'exclude' => [] } } => 'link_checker.check.images.exclude must be a set of options',
      { 'defaults' => { 'exclude' => { 'hosts' => [] } } } =>
        'Unknown link_checker.check.defaults.exclude option: hosts. Valid options: domains, urls, paths',
      { 'images' => { 'exclude' => { 'paths' => ['('] } } } => 'link_checker.check.images.exclude.paths must be'
    }.each { |raw, message| expect(error(raw)).to start_with(message) }
  end
end
