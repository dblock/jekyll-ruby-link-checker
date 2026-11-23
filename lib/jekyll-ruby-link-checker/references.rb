# frozen_string_literal: true

require 'cgi'

module Jekyll
  module RubyLinkChecker
    # Finds what a page references that should be checked, with its kind, by matching each element against the
    # selectors of each kind. Attribute values are HTML-decoded; empty links and a bare `#` are left out.
    class References
      TAG = /<([a-z][a-z0-9-]*)(\s[^>]*)?>/im
      ATTRIBUTE = %r{([^\s=/>"']+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))}m

      def initialize(kinds)
        @kinds = kinds
      end

      # Returns pairs of a kind and a URL.
      def scan(html)
        references = html.scan(TAG).flat_map do |tag, attributes|
          attributes = attributes(attributes.to_s)
          @kinds.flat_map { |kind| kind.urls(tag.downcase, attributes).map { |url| [kind, url] } }
        end
        references.reject { |_kind, href| href.empty? || href == '#' }
      end

      private

      # Attributes by lowercase name, HTML-decoded.
      def attributes(text)
        text.scan(ATTRIBUTE).to_h do |name, double, single, bare|
          [name.downcase, CGI.unescapeHTML((double || single || bare).strip)]
        end
      end
    end
  end
end
