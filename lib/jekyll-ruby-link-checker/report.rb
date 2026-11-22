# frozen_string_literal: true

require 'fileutils'

module Jekyll
  module RubyLinkChecker
    # Raised at the end of a build that found dead links, so the build fails, unless dead links are only reported.
    class DeadLinksError < StandardError; end

    # Counts checked links and collects dead ones with the pages that link to them.
    class Report
      attr_reader :counts, :failures, :unverified

      # A Markdown report starts with this marker, so a workflow can read the number of dead links.
      MARKER = 'jekyll-ruby-link-checker dead links:'

      # Writes a Markdown report to `file`, when set, at the end of the build, and fails the build on dead links
      # unless `fail_on_dead_links` is false. `changed_pages` counts the pages checked when only changed ones are.
      def initialize(verbose:, file: nil, fail_on_dead_links: true, changed_pages: nil)
        @verbose = verbose
        @file = file
        @fail_on_dead_links = fail_on_dead_links
        @changed_pages = changed_pages
        @counts = Hash.new(0)
        @failures = {}
        @unverified = {}
      end

      def count(kind)
        @counts[kind] += 1
      end

      def fail(url, locations, reason)
        add(@failures, url, locations, reason)
      end

      # Records the final result of an external link from ruby-link-checker. Links blocked by bot protection may work,
      # so they're unverified rather than dead, and don't fail the build.
      def record(result)
        url = result.uri.to_s
        count(:cached) if result.cached?
        return log(url, result.cached? ? 'OK (cached)' : 'OK') if result.success?

        log(url, result.blocked? ? "#{result.reason}, unverified" : result.reason)
        add(result.blocked? ? @unverified : @failures, url, result.options[:locations], result.reason)
      end

      def log(url, status)
        Jekyll.logger.info('LinkChecker:', "#{url}: #{status}") if @verbose
      end

      def finish
        Jekyll.logger.info('LinkChecker:', summary)
        write(@file) if @file
        warn_unverified
        return if @failures.empty?

        unless @fail_on_dead_links
          Jekyll.logger.warn('LinkChecker:', message)
          return
        end

        Jekyll.logger.error('LinkChecker:', message)
        raise DeadLinksError, message
      end

      def summary
        "Checked #{@counts[:internal]} internal and #{@counts[:external]} external links " \
          "(#{@counts[:cached]} cached)#{scope}, skipped #{@counts[:excluded]}.#{unverified_summary}"
      end

      def markdown
        lines = ["<!-- #{MARKER} #{@failures.size} -->", '', summary, '']
        lines += @failures.empty? ? ['No dead links.'] : table(@failures)
        lines += ['', '## Unverified Links', '', UNVERIFIED, '', *table(@unverified)] unless @unverified.empty?
        "#{lines.join("\n")}\n"
      end

      def message
        "Found #{plural(@failures.size, 'dead link')}:\n#{list(@failures)}"
      end

      def unverified_message
        "Couldn't verify #{plural(@unverified.size, 'link')}, which bot protection blocked:\n#{list(@unverified)}"
      end

      UNVERIFIED = 'Bot protection blocked these checks, so these links may work. Check them in a browser.'

      private

      def add(links, url, locations, reason)
        links[url] ||= { reason: reason, locations: Set.new }
        links[url][:locations].merge(Array(locations))
      end

      def warn_unverified
        Jekyll.logger.warn('LinkChecker:', unverified_message) unless @unverified.empty?
      end

      def plural(count, noun)
        "#{count} #{noun}#{'s' unless count == 1}"
      end

      def list(links)
        links.sort.map { |url, link| "#{url} (#{link[:reason]}), linked from #{link[:locations].sort.join(', ')}" }
             .join("\n")
      end

      def unverified_summary
        @unverified.empty? ? '' : " Couldn't verify #{plural(@unverified.size, 'link')}."
      end

      def table(links)
        ['| Link | Reason | Linked From |', '| --- | --- | --- |', *rows(links)]
      end

      def scope
        return '' unless @changed_pages

        " on #{@changed_pages} changed page#{'s' unless @changed_pages == 1}"
      end

      def write(file)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, markdown)
      end

      def rows(links)
        links.sort.map do |url, link|
          locations = link[:locations].sort.map { |location| cell(location) }.join(', ')
          "| #{cell(url)} | #{cell(link[:reason])} | #{locations} |"
        end
      end

      # Table cells can't contain pipes or line breaks.
      def cell(text)
        text.to_s.gsub('|', '\\|').gsub(/\s+/, ' ')
      end
    end
  end
end
