# frozen_string_literal: true

require 'json'

module Jekyll
  module RubyLinkChecker
    # The dead links of an earlier build, such as of the default branch, by URL, with their reason and the pages that
    # linked to them, in a JSON file. A build compares its dead links with them to tell new ones from existing ones.
    class Baseline
      VERSION = 1

      attr_reader :links

      # Returns nil when there's no file. A file that can't be read is ignored with a warning, rather than failing the
      # build, because it's usually a cache that a later build replaces.
      def self.read(file)
        return nil unless file && File.file?(file)

        new(parse(JSON.parse(File.read(file))))
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError => e
        Jekyll.logger.warn('LinkChecker:', "Ignoring the baseline in #{file}, which can't be read: #{e.message}")
        nil
      end

      def self.parse(data)
        raise JSON::ParserError, "expected version #{VERSION}" unless data.is_a?(Hash) && data['version'] == VERSION

        data.fetch('dead_links').to_h do |link|
          [link.fetch('url'), { reason: link.fetch('reason'), locations: Set.new(link.fetch('locations')) }]
        end
      end

      # Writes `links`, by URL, with their reason and locations.
      def self.write(file, links)
        FileUtils.mkdir_p(File.dirname(file))
        dead_links = links.sort.map do |url, link|
          { 'url' => url, 'reason' => link[:reason], 'locations' => link[:locations].sort }
        end
        File.write(file, "#{JSON.pretty_generate('version' => VERSION, 'dead_links' => dead_links)}\n")
      end

      def initialize(links)
        @links = links
      end

      def include?(url)
        @links.key?(url)
      end
    end
  end
end
