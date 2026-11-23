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
        content = page.content.to_s
        scan(content, page.relative_path, &)
        layout = @layouts && @site.layouts[page.data['layout']]
        each_in_layout(page.output.to_s, content, layout.relative_path.delete_prefix('/'), &) if layout
      end

      private

      # The output usually contains the content as it is, so only what's around it is scanned again. A layout can
      # change the content, for example with a filter, and then the references of the content are left out of the
      # whole output once each.
      def each_in_layout(output, content, location, &)
        start = output.index(content)
        return each_not_in(output, content, location, &) unless start

        scan(output[0, start], location, &)
        scan(output[(start + content.length)..], location, &)
      end

      def each_not_in(output, content, location)
        remaining = @references.scan(content).tally
        @references.scan(output).each do |reference|
          next remaining[reference] -= 1 if remaining[reference].to_i.positive?

          yield location, *reference
        end
      end

      def scan(html, location)
        @references.scan(html).each { |kind, href| yield location, kind, href }
      end
    end
  end
end
