# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Settings from `link_checker` in `_config.yml`, validated when the build starts.
    class Configuration
      DURATION_UNITS = { 's' => 1, 'm' => 60, 'h' => 3600, 'd' => 86_400, 'w' => 604_800 }.freeze

      # Reuses successful external checks for `ttl` from a cache `file`, relative to the site source.
      Cache = Data.define(:file, :ttl) do
        def initialize(file: nil, ttl: '30d')
          super(file: file, ttl: Configuration.duration(ttl, 'cache.ttl'))
        end
      end

      # Links that are never checked: external hosts and their subdomains, exact URLs, and path patterns.
      Exclude = Data.define(:domains, :urls, :paths) do
        def initialize(domains: [], urls: [], paths: [])
          super(
            domains: Configuration.list(domains, 'exclude.domains').map(&:downcase),
            urls: Configuration.list(urls, 'exclude.urls'),
            paths: Configuration.list(paths, 'exclude.paths').map { |path| Configuration.pattern(path) }
          )
        end
      end

      OPTIONS = %w[cache exclude concurrency retries user_agent verbose].freeze

      attr_reader :cache, :exclude, :concurrency, :retries, :user_agent

      def self.duration(value, name)
        return value if value.is_a?(Integer) && value.positive?

        match = /\A(\d+)\s*([smhdw]?)\z/.match(value.to_s.strip)
        invalid!(name, value, 'a positive number of seconds or a duration such as 12h or 30d') unless match

        seconds = Integer(match[1], 10) * DURATION_UNITS.fetch(match[2], 1)
        invalid!(name, value, 'a positive duration') unless seconds.positive?
        seconds
      end

      def self.list(value, name)
        invalid!(name, value, 'a list') unless value.is_a?(Array)

        value.map(&:to_s)
      end

      def self.pattern(value)
        Regexp.new(value)
      rescue RegexpError => e
        invalid!('exclude.paths', value, "a regular expression (#{e.message})")
      end

      def self.invalid!(name, value, expected)
        option = name.empty? ? 'link_checker' : "link_checker.#{name}"
        raise Jekyll::Errors::InvalidConfigurationError, "#{option} must be #{expected}, got #{value.inspect}"
      end

      def self.known!(options, valid, name)
        unknown = options.keys.map(&:to_s) - valid.map(&:to_s)
        return if unknown.empty?

        option = name.empty? ? 'link_checker' : "link_checker.#{name}"
        raise Jekyll::Errors::InvalidConfigurationError,
              "Unknown #{option} option: #{unknown.join(', ')}. Valid options: #{valid.join(', ')}"
      end

      def initialize(raw)
        raw ||= {}
        self.class.invalid!('', raw, 'a set of options') unless raw.is_a?(Hash)
        self.class.known!(raw, OPTIONS, '')
        read(raw)
      end

      def verbose?
        @verbose
      end

      private

      def read(raw)
        @cache = section(Cache, raw['cache'], 'cache')
        @exclude = section(Exclude, raw['exclude'], 'exclude')
        @concurrency = positive_integer(raw.fetch('concurrency', 5), 'concurrency')
        @retries = non_negative_integer(raw.fetch('retries', 1), 'retries')
        @user_agent = raw['user_agent']&.to_s
        @verbose = raw.fetch('verbose', false) == true
      end

      def section(klass, value, name)
        return klass.new if value.nil?

        self.class.invalid!(name, value, 'a set of options') unless value.is_a?(Hash)

        options = value.transform_keys(&:to_sym)
        self.class.known!(options, klass.members, name)

        klass.new(**options)
      end

      def positive_integer(value, name)
        self.class.invalid!(name, value, 'a positive integer') unless value.is_a?(Integer) && value.positive?
        value
      end

      def non_negative_integer(value, name)
        self.class.invalid!(name, value, 'zero or a positive integer') unless value.is_a?(Integer) && !value.negative?
        value
      end
    end
  end
end
