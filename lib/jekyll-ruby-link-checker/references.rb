# frozen_string_literal: true

require 'cgi'

module Jekyll
  module RubyLinkChecker
    # Finds what a page references that should be checked, with its kind, by matching each element against the
    # selectors of each kind. Attribute values are HTML-decoded; empty links and a bare `#` are left out.
    class References
      ATTRIBUTE = %r{([^\s=/>"']+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"']+))}m

      # Attributes by lowercase name, HTML-decoded.
      def self.attributes(text)
        text.scan(ATTRIBUTE).to_h do |name, double, single, bare|
          [name.downcase, CGI.unescapeHTML((double || single || bare).strip)]
        end
      end

      # Only the tags that a kind's selectors name are read, which skips the attributes of most elements of a page.
      def initialize(kinds)
        @kinds = kinds.flat_map { |kind| kind.tag_names.map { |tag| [tag, kind] } }
                      .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
        @tag = /<(#{alternatives(@kinds.keys)})(\s[^>]*)?>/im
      end

      # Returns pairs of a kind and a URL.
      def scan(html)
        references = []
        html.scan(@tag) do |tag, text|
          attributes = self.class.attributes(text.to_s)
          tag = tag.downcase
          @kinds[tag].each { |kind| kind.urls(tag, attributes).each { |url| references << [kind, url] } }
        end
        references.reject { |_kind, href| href.empty? || href == '#' }
      end

      private

      # Longer names first, so that `area` isn't read as `a`.
      def alternatives(tags)
        tags.sort_by { |tag| -tag.length }.map { |tag| Regexp.escape(tag) }.join('|')
      end
    end
  end
end
