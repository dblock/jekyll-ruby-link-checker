# frozen_string_literal: true

require 'fileutils'

module Jekyll
  module RubyLinkChecker
    # Raised at the end of a build that found dead links, so the build fails.
    class DeadLinksError < StandardError; end

    # Counts checked links and collects dead ones with the pages that link to them.
    class Report
      attr_reader :counts, :failures

      # A Markdown report starts with this marker, so a workflow can read the number of dead links.
      MARKER = 'jekyll-ruby-link-checker dead links:'

      # Writes a Markdown report to `file`, when set, at the end of the build.
      def initialize(verbose:, file: nil)
        @verbose = verbose
        @file = file
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
        write(@file) if @file
        return if @failures.empty?

        Jekyll.logger.error('LinkChecker:', message)
        raise DeadLinksError, message
      end

      def summary
        "Checked #{@counts[:internal]} internal and #{@counts[:external]} external links " \
          "(#{@counts[:cached]} cached), skipped #{@counts[:excluded]}."
      end

      def markdown
        lines = ["<!-- #{MARKER} #{@failures.size} -->", '', summary, '']
        table = ['| Link | Reason | Linked From |', '| --- | --- | --- |', *rows]
        lines += @failures.empty? ? ['No dead links.'] : table
        "#{lines.join("\n")}\n"
      end

      def message
        lines = @failures.sort.map do |url, failure|
          "#{url} (#{failure[:reason]}), linked from #{failure[:locations].sort.join(', ')}"
        end
        "Found #{lines.size} dead link#{'s' unless lines.size == 1}:\n#{lines.join("\n")}"
      end

      private

      def write(file)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, markdown)
      end

      def rows
        @failures.sort.map do |url, failure|
          locations = failure[:locations].sort.map { |location| cell(location) }.join(', ')
          "| #{cell(url)} | #{cell(failure[:reason])} | #{locations} |"
        end
      end

      # Table cells can't contain pipes or line breaks.
      def cell(text)
        text.to_s.gsub('|', '\\|').gsub(/\s+/, ' ')
      end
    end
  end
end
