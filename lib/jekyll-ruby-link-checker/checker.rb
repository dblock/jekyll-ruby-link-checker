# frozen_string_literal: true

require 'logger'

module Jekyll
  module RubyLinkChecker
    # Collects the links of one build and checks them once the site is written.
    class Checker
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
        @kinds = {}
      end

      def collect(page)
        return unless checked?(page)

        @report.page(page.relative_path, title: page.data['title'], url: page_url(page))
        sources.each(page) { |location, kind, href| reference(page, location, kind, href) }
      end

      def verify
        internal = InternalLinks.new(@site.dest, localize: @urls.method(:localize))
        external = external_checker
        @links.each { |href, locations| queue(href, locations.to_a, internal, external) }
        external.run
        @report.finish
      end

      private

      def sources = @sources ||= Sources.new(@site, References.new(@config.check.kinds), layouts: @config.layouts?)

      # Anchors on the same page are checked against it, and anything else once the site is written. A layout is
      # listed in the report without a title or a link.
      def reference(page, location, kind, href)
        @report.page(location) unless location == page.relative_path
        return (check_anchor(page, kind, href, location) if kind.anchors) if kind.link? && href.start_with?('#')

        add(location, kind, @urls.resolve(page.url, href))
      end

      # A URL that is both linked and shown as an image keeps the kind it was first found as.
      def add(location, kind, url)
        @links[url] << location
        @kinds[url] ||= kind
      end

      def new_report
        Report.new(verbose: @config.verbose?, file: @config.report_file(@site.source),
                   fail_on_dead_links: @config.fail_on_dead_links?, changed_pages: @only&.size,
                   permanent_redirects: @config.permanent_redirects?).tap { |report| report.site_url = site_url }
      end

      # Pages that opt out with `link_checker: false`, outputs other than HTML, and, with LINK_CHECKER_CHANGED_FILES,
      # pages that didn't change are not checked.
      def checked?(page)
        page.data['link_checker'] != false && HTML_EXTENSIONS.include?(page.output_ext.to_s.downcase) &&
          (@only.nil? || @only.include?(page.relative_path))
      end

      def site_url = @site.config['url'].to_s.empty? ? nil : @site.config['url']

      def page_url(page)
        "#{site_url}#{@site.baseurl}#{page.url}" if site_url
      end

      # An anchor in a layout is reported once, from the layout, rather than for every page.
      def check_anchor(page, kind, href, location)
        return if InternalLinks.anchor?(page.output.to_s, href[1..])

        @report.fail(location == page.relative_path ? "#{page.url}#{href}" : href, location, 'anchor not found',
                     warn: !kind.fail)
      end

      def queue(href, locations, internal, external)
        kind = @kinds[href]
        url = @urls.localize(href)
        return @report.count(:excluded) if @urls.excluded?(url, kind.exclude) || !kind.checks?(Urls.external?(url))

        if Urls.external?(url)
          @report.count(:external)
          external.check(url, locations: locations, kind: kind.label, warn: !kind.fail)
        else
          check_internal(kind, href, url, locations, internal)
        end
      end

      # A missing image is reported as such, rather than as a missing page. Without `anchors`, only the page is checked.
      def check_internal(kind, href, url, locations, internal)
        @report.count(:internal)
        reason = internal.check(kind.anchors ? url : url.split('#', 2).first)
        reason = "#{kind.label} not found" if reason == 'page not found' && !kind.link?
        @report.log(href, reason || 'OK')
        @report.fail(href, locations, reason, warn: !kind.fail) if reason
      end

      def external_checker
        checker = LinkChecker::Typhoeus::Hydra::Checker.new(**@config.checker_options(@site.source, full: @only.nil?))
        # `complete` is published once per link with its final result, unlike `result`, which is published for every
        # attempt, including each redirect. Cache hits are reported when a link is queued, before the checker runs.
        checker.on(:complete) { |result| @report.record(result) }
        checker
      end
    end
  end
end
