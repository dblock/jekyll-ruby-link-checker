# frozen_string_literal: true

require 'uri'

module Jekyll
  module RubyLinkChecker
    # Turns the links found in pages into what gets checked: paths for the site's own pages, and URLs elsewhere.
    class Urls
      EXTERNAL = %r{\Ahttps?://}i
      SCHEME = /\A[a-z][a-z0-9+.-]*:/i

      def initialize(site, exclude)
        @exclude = exclude
        root = "#{site.config['url'].to_s.chomp('/')}#{site.baseurl.to_s.chomp('/')}"
        @site_url = %r{\A#{Regexp.escape(root)}(/.*|\z)}i unless site.config['url'].to_s.empty?
      end

      def self.external?(url)
        url.match?(EXTERNAL)
      end

      # Resolves a relative link, such as `../about/`, against the URL of the page that contains it.
      def resolve(page_url, href)
        return href if href.start_with?('/') || href.match?(SCHEME)

        resolved = URI.join('https://site.invalid', page_url.to_s, href)
        resolved.fragment ? "#{resolved.path}##{resolved.fragment}" : resolved.path
      rescue URI::Error
        href
      end

      # Turns scheme-relative links into `https` URLs, and absolute links to the site itself into paths.
      def localize(href)
        url = href.start_with?('//') ? "https:#{href}" : href
        match = @site_url&.match(url)
        return url unless match

        match[1].empty? ? '/' : match[1]
      end

      # Links with other schemes, such as `mailto:`, and configured exclusions are not checked.
      def excluded?(url)
        return true if url.match?(SCHEME) && !self.class.external?(url)
        return true if excluded_url?(url)
        return true if @exclude.paths.any? { |pattern| pattern.match?(url) }

        self.class.external?(url) && excluded_domain?(url)
      end

      private

      # Excluded URLs are exact, or regular expressions.
      def excluded_url?(url)
        @exclude.urls.any? { |excluded| excluded.is_a?(Regexp) ? excluded.match?(url) : excluded == url }
      end

      def excluded_domain?(url)
        host = URI.parse(url).host.to_s.downcase
        @exclude.domains.any? { |domain| host == domain || host.end_with?(".#{domain}") }
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
