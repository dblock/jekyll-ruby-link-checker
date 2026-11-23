# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Settings from `link_checker` in `_config.yml`, validated when the build starts.
    class Configuration
      # Reuses successful external checks for `ttl`, and unverified ones for `blocked_ttl`, from a cache `file`,
      # relative to the site source, and with `prune`, removes entries of links that a full check no longer checks.
      Cache = Data.define(:file, :ttl, :blocked_ttl, :prune) do
        def initialize(file: nil, ttl: '30d', blocked_ttl: nil, prune: false)
          super(
            file: file,
            ttl: Values.duration(ttl, 'cache.ttl'),
            blocked_ttl: blocked_ttl.nil? ? nil : Values.duration(blocked_ttl, 'cache.blocked_ttl'),
            prune: Values.boolean(prune, 'cache.prune')
          )
        end
      end

      # Links that are never checked: external hosts and their subdomains, exact URLs, and path patterns.
      Exclude = Data.define(:domains, :urls, :paths) do
        def initialize(domains: [], urls: [], paths: [])
          super(
            domains: Values.list(domains, 'exclude.domains').map(&:downcase),
            urls: Values.list(urls, 'exclude.urls').map { |url| Values.string_or_pattern(url, 'exclude.urls') },
            paths: Values.list(paths, 'exclude.paths').map { |path| Values.pattern(path, 'exclude.paths') }
          )
        end
      end

      # Options passed to ruby-link-checker, with its name and a reader; unset options keep its defaults.
      REQUEST_OPTIONS = {
        'blocked' => %i[blocked_status_codes status_codes],
        'detect_challenges' => %i[detect_challenges boolean],
        'timeout' => %i[timeout duration],
        'connect_timeout' => %i[connecttimeout duration],
        'host_concurrency' => %i[max_concurrency_per_host positive_integer],
        'host_interval' => %i[min_host_interval seconds],
        'headers' => %i[headers headers],
        'host_headers' => %i[host_headers host_headers]
      }.freeze

      OPTIONS = (%w[cache exclude check layouts concurrency retries user_agent verbose permanent_redirects] +
                 REQUEST_OPTIONS.keys)
                .freeze

      attr_reader :cache, :exclude, :check, :concurrency, :retries, :user_agent, :request_options

      def initialize(raw)
        raw ||= {}
        Values.invalid!('', raw, 'a set of options') unless raw.is_a?(Hash)
        Values.known!(raw, OPTIONS, '')
        read(raw)
      end

      def verbose?
        @verbose
      end

      def layouts?
        @layouts
      end

      def permanent_redirects?
        @permanent_redirects
      end

      # LINK_CHECKER_CACHE overrides the configured cache file, for example in a CI workflow. Only a `full` check
      # prunes, because a check of some pages would remove the entries of the links on the others.
      def cache_options(source, full: true)
        file = ENV.fetch('LINK_CHECKER_CACHE', '').strip
        file = @cache.file.to_s if file.empty?
        return nil if file.empty?

        options = { file: File.expand_path(file, source), ttl: @cache.ttl }
        options[:blocked_ttl] = @cache.blocked_ttl if @cache.blocked_ttl
        options[:prune] = true if @cache.prune && full
        options
      end

      # LINK_CHECKER_REPORT names a file for a Markdown report, for example in a CI workflow.
      def report_file(source)
        file = ENV.fetch('LINK_CHECKER_REPORT', '').strip
        file.empty? ? nil : File.expand_path(file, source)
      end

      # LINK_CHECKER_CHANGED_FILES names a file that lists changed files, one per line, relative to the site source,
      # to only check the pages that changed, for example in a pull request.
      def changed_files(source)
        file = ENV.fetch('LINK_CHECKER_CHANGED_FILES', '').strip
        file.empty? ? nil : File.expand_path(file, source)
      end

      # LINK_CHECKER_FAIL=0 reports dead links without failing the build, for example on pull requests.
      def fail_on_dead_links?
        !%w[0 false no off].include?(ENV.fetch('LINK_CHECKER_FAIL', '').strip.downcase)
      end

      private

      def read(raw)
        read_sections(raw)
        @concurrency = Values.positive_integer(raw.fetch('concurrency', 5), 'concurrency')
        @retries = Values.non_negative_integer(raw.fetch('retries', 1), 'retries')
        @user_agent = raw['user_agent']&.to_s
        @verbose = raw.fetch('verbose', false) == true
        @layouts = Values.boolean(raw.fetch('layouts', true), 'layouts')
        @permanent_redirects = Values.boolean(raw.fetch('permanent_redirects', false), 'permanent_redirects')
        @request_options = read_request_options(raw)
      end

      def read_sections(raw)
        @cache = section(Cache, raw['cache'], 'cache')
        @exclude = section(Exclude, raw['exclude'], 'exclude')
        @check = Check.new(raw['check'])
      end

      def read_request_options(raw)
        REQUEST_OPTIONS.select { |name, _| raw.key?(name) }.to_h do |name, (option, reader)|
          [option, Values.public_send(reader, raw[name], name)]
        end
      end

      def section(klass, value, name)
        return klass.new if value.nil?

        Values.invalid!(name, value, 'a set of options') unless value.is_a?(Hash)

        options = value.transform_keys(&:to_sym)
        Values.known!(options, klass.members, name)

        klass.new(**options)
      end
    end
  end
end
