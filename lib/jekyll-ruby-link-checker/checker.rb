# frozen_string_literal: true

require 'logger'

module Jekyll
  module RubyLinkChecker
    # Collects the links of one build and checks them once the site is written.
    class Checker
      HREF = /<a\s[^>]*?href=(["'])(.*?)\1/im
      HTML_EXTENSIONS = %w[.html .htm].freeze

      class << self
        attr_reader :current

        # Starts checking when LINK_CHECKER is set, so ordinary builds and `jekyll serve` stay fast.
        def start(site)
          @current = enabled? ? new(site) : nil
        end

        def finish
          checker = @current
          @current = nil
          checker&.verify
        end

        def enabled?
          value = ENV.fetch('LINK_CHECKER', '').strip.downcase
          !value.empty? && !%w[0 false no off].include?(value)
        end
      end

      attr_reader :config, :links, :report

      def initialize(site)
        @site = site
        @config = Configuration.new(site.config['link_checker'])
        @urls = Urls.new(site, @config.exclude)
        @only = ChangedFiles.pages(site, @config.changed_files(site.source))
        @report = new_report
        @links = Hash.new { |hash, url| hash[url] = Set.new }
      end

      def collect(page)
        return unless checked?(page)

        hrefs(page).each do |href|
          next check_anchor(page, href) if href.start_with?('#')

          @links[@urls.resolve(page.url, href)] << page.relative_path
        end
      end

      def verify
        internal = InternalLinks.new(@site.dest, localize: @urls.method(:localize))
        external = external_checker
        @links.each { |href, locations| queue(href, locations.to_a, internal, external) }
        external.run
        @report.finish
      end

      private

      def new_report
        Report.new(verbose: @config.verbose?, file: @config.report_file(@site.source),
                   fail_on_dead_links: @config.fail_on_dead_links?, changed_pages: @only&.size)
      end

      # Pages that opt out with `link_checker: false`, outputs other than HTML, and, with LINK_CHECKER_CHANGED_FILES,
      # pages that didn't change are not checked.
      def checked?(page)
        page.data['link_checker'] != false && HTML_EXTENSIONS.include?(page.output_ext.to_s.downcase) &&
          (@only.nil? || @only.include?(page.relative_path))
      end

      def hrefs(page)
        page.content.to_s.scan(HREF).map { |_, href| CGI.unescapeHTML(href.strip) }.reject do |href|
          href.empty? || href == '#'
        end
      end

      def check_anchor(page, href)
        return if InternalLinks.anchor?(page.output.to_s, href[1..])

        @report.fail("#{page.url}#{href}", page.relative_path, 'anchor not found')
      end

      def queue(href, locations, internal, external)
        url = @urls.localize(href)
        return @report.count(:excluded) if @urls.excluded?(url)

        if Urls.external?(url)
          @report.count(:external)
          external.check(url, locations: locations)
        else
          check_internal(href, url, locations, internal)
        end
      end

      def check_internal(href, url, locations, internal)
        @report.count(:internal)
        reason = internal.check(url)
        @report.log(href, reason || 'OK')
        @report.fail(href, locations, reason) if reason
      end

      def external_checker
        checker = LinkChecker::Typhoeus::Hydra::Checker.new(**checker_options)
        # `complete` is published once per link with its final result, unlike `result`, which is published for every
        # attempt, including each redirect. Cache hits are reported when a link is queued, before the checker runs.
        checker.on(:complete) { |result| @report.record(result) }
        checker
      end

      def checker_options
        options = {
          logger: @config.verbose? ? Jekyll.logger : Logger.new(IO::NULL),
          hydra: { max_concurrency: @config.concurrency },
          retries: @config.retries,
          cache: @config.cache_options(@site.source)
        }
        options[:user_agent] = @config.user_agent if @config.user_agent
        options
      end
    end
  end
end
