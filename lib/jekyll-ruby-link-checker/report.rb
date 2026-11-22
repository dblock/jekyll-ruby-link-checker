# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Raised at the end of a build that found dead links, so the build fails.
    class DeadLinksError < StandardError; end

    # Counts checked links and collects dead ones with the pages that link to them.
    class Report
      attr_reader :counts, :failures

      def initialize(verbose:)
        @verbose = verbose
        @counts = Hash.new(0)
        @failures = {}
      end

      def count(kind)
        @counts[kind] += 1
      end

      def fail(url, locations, reason)
        @failures[url] ||= { reason: reason, locations: Set.new }
        @failures[url][:locations].merge(Array(locations))
      end

      def log(url, status)
        Jekyll.logger.info('LinkChecker:', "#{url}: #{status}") if @verbose
      end

      def finish
        Jekyll.logger.info('LinkChecker:', summary)
        return if @failures.empty?

        Jekyll.logger.error('LinkChecker:', message)
        raise DeadLinksError, message
      end

      def summary
        "Checked #{@counts[:internal]} internal and #{@counts[:external]} external links " \
          "(#{@counts[:cached]} cached), skipped #{@counts[:excluded]}."
      end

      def message
        lines = @failures.sort.map do |url, failure|
          "#{url} (#{failure[:reason]}), linked from #{failure[:locations].sort.join(', ')}"
        end
        "Found #{lines.size} dead link#{'s' unless lines.size == 1}:\n#{lines.join("\n")}"
      end
    end
  end
end
