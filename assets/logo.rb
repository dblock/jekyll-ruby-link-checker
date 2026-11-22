# frozen_string_literal: true

# Generates the jekyll-ruby-link-checker logo in this directory.
#
#   ruby assets/logo.rb
#
# The logo is a page with a link, and the faceted gem and checkmark of the ruby-link-checker logo. Colors are from the
# Ruby logo at https://www.ruby-lang.org/images/header-ruby-logo.svg.

# Draws the logo.
module Logo
  # Ruby logo colors, light to dark, and the grays of the page.
  COLORS = {
    highlight: '#fcb19d',
    bright: '#e62923',
    red: '#e2242a',
    medium: '#cf251f',
    deep: '#b8211c',
    dark: '#9e0c00',
    paper: '#ffffff',
    fold: '#eef1f4',
    line: '#d0d7de'
  }.freeze

  # The ruby-link-checker gem on a 256x256 canvas: a crown above the girdle (y=100) and a pavilion down to the tip.
  FACETS = [
    [[28, 100], [76, 52], [92, 100], :bright],
    [[76, 52], [128, 52], [92, 100], :medium],
    [[128, 52], [164, 100], [92, 100], :highlight],
    [[128, 52], [180, 52], [164, 100], :medium],
    [[180, 52], [228, 100], [164, 100], :deep],
    [[28, 100], [92, 100], [128, 208], :bright],
    [[92, 100], [164, 100], [128, 208], :red],
    [[164, 100], [228, 100], [128, 208], :dark]
  ].freeze

  CHECK = '<path d="M90 116 L118 144 L170 92" fill="none" stroke="#ffffff" stroke-width="18" ' \
          'stroke-linecap="round" stroke-linejoin="round"/>'

  # A page with a folded corner, two lines of text, and a link, on a 256x256 canvas.
  PAGE = [
    %(<path d="M44 14 H168 L212 58 V242 H44 Z" fill="#{COLORS[:paper]}" stroke="#{COLORS[:line]}" ),
    %(stroke-width="10" stroke-linejoin="round"/>),
    %(<path d="M168 14 V58 H212" fill="#{COLORS[:fold]}" stroke="#{COLORS[:line]}" stroke-width="10" ),
    %(stroke-linejoin="round"/>),
    %(<rect x="72" y="82" width="112" height="16" rx="8" fill="#{COLORS[:line]}"/>),
    %(<rect x="72" y="112" width="88" height="16" rx="8" fill="#{COLORS[:line]}"/>),
    %(<rect x="72" y="142" width="60" height="16" rx="8" fill="#{COLORS[:red]}"/>)
  ].join

  # Where the gem sits on the page, as a badge in the lower right.
  BADGE = 'translate(110 126) scale(0.6)'

  module_function

  def gem_shapes
    polygons = FACETS.map do |*points, color|
      %(<polygon points="#{points.map { |x, y| "#{x},#{y}" }.join(' ')}" fill="#{COLORS[color]}"/>)
    end
    polygons.join + CHECK
  end

  def svg
    shapes = %(#{PAGE}<g transform="#{BADGE}">#{gem_shapes}</g>)
    %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">) \
      "<title>jekyll-ruby-link-checker</title>#{shapes}</svg>\n"
  end

  def write(directory)
    File.write(File.join(directory, 'logo.svg'), svg)
  end
end

Logo.write(__dir__)
