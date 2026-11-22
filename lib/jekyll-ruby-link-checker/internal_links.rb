# frozen_string_literal: true

require 'cgi'

module Jekyll
  module RubyLinkChecker
    # Checks links to pages of the built site, and anchors in them, against the destination directory.
    class InternalLinks
      MAX_REDIRECTS = 10
      REDIRECT_TITLE = '<title>Redirecting'
      HREF = /<a\s[^>]*?href=(["'])(.*?)\1/im

      # `localize` turns absolute links to the site itself into paths.
      def initialize(destination, localize: ->(url) { url })
        @destination = destination
        @localize = localize
        @contents = {}
      end

      # Returns nil when the link works, or a reason it doesn't.
      def check(url, redirects = 0)
        path, fragment = url.split('#', 2)
        fragment = nil if fragment.to_s.empty?
        content = read(path)
        return 'page not found' if content.nil?
        return follow(content, fragment, redirects) if content.include?(REDIRECT_TITLE)
        return nil if fragment.nil? || self.class.anchor?(content, fragment)

        "anchor ##{fragment} not found"
      end

      def self.anchor?(content, fragment)
        id = Regexp.escape(CGI.unescape(fragment))
        content.match?(/<[a-z0-9-]+\s[^>]*?(?:id|name)=(["'])#{id}\1/i)
      end

      private

      # Redirects to other sites are left unchecked here, and a redirect loop stops after MAX_REDIRECTS.
      def follow(content, fragment, redirects)
        target = redirect_target(content)
        return nil if target.nil? || !target.start_with?('/') || redirects >= MAX_REDIRECTS

        target = "#{target.split('#', 2).first}##{fragment}" if fragment
        check(target, redirects + 1)
      end

      def read(path)
        file = files_for(path).find { |candidate| File.file?(candidate) }
        return nil unless file

        @contents[file] ||= File.read(file)
      end

      # A path without an extension is a directory index, or a page served without its .html extension.
      def files_for(path)
        path = CGI.unescape(path.to_s)
        path = "/#{path}" unless path.start_with?('/')
        return [File.join(@destination, path)] unless File.extname(path).empty? || path.end_with?('/')

        directory = path.end_with?('/') ? path : "#{path}/"
        candidates = [File.join(@destination, directory, 'index.html')]
        candidates << File.join(@destination, "#{directory.chomp('/')}.html") unless directory == '/'
        candidates
      end

      def redirect_target(content)
        match = content.match(HREF)
        match && @localize.call(CGI.unescapeHTML(match[2]))
      end
    end
  end
end
