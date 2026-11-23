# frozen_string_literal: true

RSpec.describe Jekyll::RubyLinkChecker::Selector do
  def selector(text)
    described_class.parse(text, 'check.links.tags')
  end

  it 'matches a tag' do
    expect(selector('img').match?('img', {})).to be(true)
    expect(selector('IMG').match?('img', {})).to be(true)
    expect(selector('img').match?('source', {})).to be(false)
  end

  it 'matches words that attributes must contain, in any case' do
    stylesheet = selector('link[rel~=stylesheet]')

    expect(stylesheet.match?('link', 'rel' => 'alternate Stylesheet')).to be(true)
    expect(stylesheet.match?('link', 'rel' => 'icon')).to be(false)
    expect(stylesheet.match?('link', {})).to be(false)
    icon = selector('link[rel~="icon"][type~=image/png]')
    expect(icon.match?('link', 'rel' => 'icon', 'type' => 'image/png')).to be(true)
  end

  it 'rules out words with not' do
    links = selector('link:not([rel~=preconnect], [rel~=stylesheet])')

    expect(links.match?('link', 'rel' => 'icon')).to be(true)
    expect(links.match?('link', 'rel' => 'preconnect')).to be(false)
    expect(links.match?('link', 'rel' => 'stylesheet')).to be(false)
  end

  it 'rejects other selectors' do
    ['', 'img.photo', 'div img', 'link[rel=icon]', 'link:not(.x)', '[rel~=icon]'].each do |text|
      expect { selector(text) }
        .to raise_error(Jekyll::Errors::InvalidConfigurationError, /\Alink_checker.check.links.tags must be a selector/)
    end
  end
end
