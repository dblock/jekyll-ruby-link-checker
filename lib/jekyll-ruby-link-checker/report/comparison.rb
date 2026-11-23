# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # Compares dead links with a baseline, such as those of the default branch. A dead link whose URL is in the
      # baseline already existed, and one in the baseline that the checked pages no longer link to as dead is fixed.
      # When only new dead links fail the build, new ones that failed in a way that may be temporary are warnings, and
      # without a baseline, no dead link fails the build.
      module Comparison
        attr_reader :existing, :fixed, :unclassified

        # The dead links that fail the build.
        def failing
          @fail_on == :new ? @failures : @failures.merge(@existing)
        end

        private

        def compare
          @dead = @failures.merge(@warnings)
          @existing, @fixed, @unclassified = Array.new(3) { {} }
          split_existing if @baseline
          return unless @fail_on == :new

          @baseline ? warn_flaky : unclassify
        end

        def split_existing
          @existing, @failures = @failures.partition { |url, _link| @baseline.include?(url) }.map(&:to_h)
          @fixed = @baseline.links.reject do |url, link|
            @dead.key?(url) || !link[:locations].all? { |location| @pages.key?(location) }
          end
        end

        def unclassify
          @unclassified = @failures
          @failures = {}
        end

        def warn_flaky
          flaky, @failures = @failures.partition { |_url, link| link[:reason].match?(Exclusions::FLAKY) }.map(&:to_h)
          @warnings.merge!(flaky)
        end
      end
    end
  end
end
