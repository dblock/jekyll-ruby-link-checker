# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # Compares dead links with a baseline, such as those of the default branch. A dead link whose URL is in the
      # baseline already existed, and one in the baseline that the checked pages no longer link to as dead is fixed.
      # When only new dead links fail the build, new ones that failed in a way that may be temporary are warnings, and
      # without a baseline, no dead link fails the build.
      module Comparison
        EXISTING = 'These links were already dead in the baseline, such as on the default branch.'
        FIXED = 'These links were dead in the baseline, and work now, or the checked pages no longer link to them.'
        UNCLASSIFIED = "There's no baseline, such as from the default branch, to tell new dead links from existing " \
                       "ones, so these don't fail the build. The next check of the default branch saves one."

        attr_reader :existing, :fixed, :unclassified

        # The dead links that fail the build.
        def failing
          @fail_on == :new ? @failures : @failures.merge(@existing)
        end

        private

        # The dead links that fail the build, or, without a baseline to compare them with, those that would.
        def dead_section
          return section(@unclassified, 'Dead Link', UNCLASSIFIED) unless @unclassified.empty?

          links = @baseline ? @failures : failing
          return ["No #{'new ' if @baseline}dead links."] if links.empty?

          section(links, @baseline ? 'New Dead Link' : 'Dead Link')
        end

        # Existing and fixed links are collapsed, because there are often many, and nothing to do about them here.
        def comparison_sections
          fixed = @fixed.transform_values { |link| link.merge(reason: "was #{link[:reason]}") }
          [(collapsed(@existing, 'Existing Dead Link', EXISTING) unless @existing.empty?),
           (collapsed(fixed, 'Fixed Link', FIXED) unless fixed.empty?)]
        end

        def collapsed(links, noun, note)
          ["### #{plural(links.size, noun)}", '', note, '', "<details><summary>#{plural(links.size, 'link')}</summary>",
           '', *links.sort.flat_map { |url, link| item(url, link, false) }, '', '</details>']
        end

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
