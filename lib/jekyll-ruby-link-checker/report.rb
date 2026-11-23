# frozen_string_literal: true

require 'fileutils'
require_relative 'report/formatting'
require_relative 'report/markdown'
require_relative 'report/exclusions'

module Jekyll
  module RubyLinkChecker
    # Raised at the end of a build that found dead links, so the build fails, unless dead links are only reported.
    class DeadLinksError < StandardError; end

    # Counts checked links and collects dead ones with the pages that link to them.
    class Report
      include Formatting
      include Markdown
      include Exclusions

      attr_reader :counts, :failures, :warnings, :unverified, :moved

      # Writes a Markdown report to `file`, when set, at the end of the build, and fails the build on dead links
      # unless `fail_on_dead_links` is false. `changed_pages` counts the pages checked when only changed ones are.
      # With `permanent_redirects`, working links that moved permanently are reported with their new URL.
      def initialize(verbose:, file: nil, fail_on_dead_links: true, changed_pages: nil, permanent_redirects: false)
        @verbose = verbose
        @file = file
        @fail_on_dead_links = fail_on_dead_links
        @changed_pages = changed_pages
        @permanent_redirects = permanent_redirects
        @counts = Hash.new(0)
        @failures, @warnings, @unverified, @moved, @pages = Array.new(5) { {} }
      end

      # With the site's URL, the report links to the site's pages and its dead links.
      def site_url=(url)
        @site_url = url&.delete_suffix('/')
      end

      # Remembers the title and URL of a page, by its source path, so the report can link to it.
      def page(path, title: nil, url: nil)
        @pages[path] = { title: title, url: url }
      end

      def count(kind)
        @counts[kind] += 1
      end

      # With `warn`, a dead link is listed as a warning, and doesn't fail the build.
      def fail(url, locations, reason, warn: false)
        add(warn ? @warnings : @failures, url, locations, reason)
      end

      # Records the final result of an external link from ruby-link-checker. Links blocked by bot protection may work,
      # so they're unverified rather than dead, and don't fail the build.
      def record(result)
        url = result.uri.to_s
        count(:cached) if result.cached?
        return success(url, result) if result.success?

        dead(url, result, with_kind(result.reason, result.options[:kind]))
      end

      def log(url, status)
        Jekyll.logger.info('LinkChecker:', "#{url}: #{status}") if @verbose
      end

      def finish
        Jekyll.logger.info('LinkChecker:', summary)
        write(@file) if @file
        warn_unverified_and_moved
        return if @failures.empty?
        return Jekyll.logger.warn('LinkChecker:', message) unless @fail_on_dead_links

        Jekyll.logger.error('LinkChecker:', message)
        raise DeadLinksError, message
      end

      private

      def dead(url, result, reason)
        log(url, result.blocked? ? "#{reason}, unverified" : reason)
        return add(@unverified, url, result.options[:locations], reason) if result.blocked?

        fail(url, result.options[:locations], reason, warn: result.options[:warn])
      end

      def add(links, url, locations, reason)
        links[url] ||= { reason: reason, locations: Set.new }
        links[url][:locations].merge(Array(locations))
      end

      # Says what kind of reference failed, unless it's a link, such as `image: HTTP 404`.
      def with_kind(reason, kind)
        kind.nil? || kind == 'link' ? reason : "#{kind}: #{reason}"
      end

      def success(url, result)
        log(url, result.cached? ? 'OK (cached)' : 'OK')
        return unless @permanent_redirects && result.permanent_redirect?

        add(@moved, url, result.options[:locations], result.result_uri.to_s)
      end

      # Warnings, and unverified and moved links, don't fail the build.
      def warn_unverified_and_moved
        Jekyll.logger.warn('LinkChecker:', warnings_message) unless @warnings.empty?
        Jekyll.logger.warn('LinkChecker:', unverified_message) unless @unverified.empty?
        Jekyll.logger.warn('LinkChecker:', moved_message) unless @moved.empty?
      end

      def write(file)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, markdown)
      end
    end
  end
end
