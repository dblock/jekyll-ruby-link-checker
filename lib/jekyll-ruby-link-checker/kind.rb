# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # A kind of reference, such as links or images: the elements and attributes that hold it, its `label` in reports,
    # whether references to the site itself (`internal`) and to other sites (`external`) are checked, whether dead
    # ones `fail` the build, its own `exclude` lists, and, for links, whether `anchors` are checked.
    Kind = Data.define(:name, :label, :tags, :internal, :external, :fail, :exclude, :anchors) do
      # Returns the URLs that an element with a lowercase `tag` and `attributes`, by lowercase name, holds.
      def urls(tag, attributes)
        tags.flat_map do |selector, names|
          next [] unless selector.match?(tag, attributes)

          names.flat_map { |name| attributes.key?(name) ? Kind.values(name, attributes[name]) : [] }
        end
      end

      def link?
        name == 'links'
      end

      # Whether references of this kind to other sites, or to the site itself, are checked.
      def checks?(external_url)
        external_url ? external : internal
      end

      # A srcset, including data-srcset, holds URLs followed by descriptors, such as `2x` or `640w`, separated by
      # commas. Browsers remove tabs and newlines from URLs, so a URL split across lines in the source still works.
      def self.values(name, value)
        urls = [value]
        urls = value.split(',').map { |candidate| candidate.strip.split(/\s+/).first } if name.end_with?('srcset')
        urls.map { |url| url.to_s.delete("\t\n\r") }
      end
    end
  end
end
