# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Links that are never checked: external hosts and their subdomains, exact URLs, and path patterns.
    Exclude = Data.define(:domains, :urls, :paths) do
      # `name` is where the exclusions are configured, such as `check.images.exclude`, for errors.
      def initialize(domains: [], urls: [], paths: [], name: 'exclude')
        super(
          domains: Values.list(domains, "#{name}.domains").map(&:downcase),
          urls: Values.list(urls, "#{name}.urls").map { |url| Values.string_or_pattern(url, "#{name}.urls") },
          paths: Values.list(paths, "#{name}.paths").map { |path| Values.pattern(path, "#{name}.paths") }
        )
      end
    end
  end
end
