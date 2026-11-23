# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Splits what a page references by where it comes from: its content, reported from the page, and, with
    # `layouts`, its layouts and includes, such as navigation, reported from the page's layout. Layouts repeat
    # on every page, so a broken link in them is reported once, from the layout, rather than from every page.
    class Sources
      def initialize(site, references, layouts:)
        @site = site
        @references = references
        @layouts = layouts
      end

      # Yields the location, the kind, and the URL of each reference of the page.
      def each(page, &)
        content = @references.scan(page.content.to_s)
        content.each { |kind, href| yield page.relative_path, kind, href }
        layout = @layouts && @site.layouts[page.data['layout']]
        each_in_layout(page, layout.relative_path.delete_prefix('/'), content, &) if layout
      end

      private

      # The output contains the content, so the references of the content are left out once each.
      def each_in_layout(page, location, content)
        remaining = content.tally
        @references.scan(page.output.to_s).each do |reference|
          next remaining[reference] -= 1 if remaining[reference].to_i.positive?

          yield location, *reference
        end
      end
    end
  end
end
