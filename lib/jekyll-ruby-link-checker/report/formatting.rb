# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # Text of the summary and the log messages.
      module Formatting
        def summary
          "Checked #{@counts[:internal]} internal and #{@counts[:external]} external links " \
            "(#{@counts[:cached]} cached)#{scope}, skipped #{@counts[:excluded]}.#{notes}"
        end

        def message
          noun = @baseline && @fail_on == :new ? 'new dead link' : 'dead link'
          "Found #{plural(failing.size, noun)}:\n#{list(failing)}"
        end

        def unclassified_message
          "There's no baseline to tell new dead links from existing ones, so " \
            "#{plural(@unclassified.size, 'dead link')} don't fail the build:\n#{list(@unclassified)}"
        end

        def warnings_message
          "Found #{plural(@warnings.size, 'dead link')} that don't fail the build:\n#{list(@warnings)}"
        end

        def unverified_message
          "Couldn't verify #{plural(@unverified.size, 'link')}, which bot protection blocked:\n#{list(@unverified)}"
        end

        def moved_message
          "#{plural(@moved.size, 'link')} moved permanently:\n#{list(@moved, '%<url>s to %<reason>s')}"
        end

        private

        def plural(count, noun)
          "#{count} #{noun}#{'s' unless count == 1}"
        end

        def list(links, template = '%<url>s (%<reason>s)')
          links.sort.map do |url, link|
            "#{format(template, url: url, reason: link[:reason])}, linked from #{link[:locations].sort.join(', ')}"
          end.join("\n")
        end

        def notes
          "#{comparison_summary}#{warnings_summary}#{unverified_summary}#{moved_summary}"
        end

        # How many dead links already existed, and how many were fixed, compared with the baseline.
        def comparison_summary
          return '' unless @baseline

          " #{plural(@existing.size, 'dead link')} already existed, #{plural(@fixed.size, 'link')} fixed."
        end

        def warnings_summary
          @warnings.empty? ? '' : " #{plural(@warnings.size, 'warning')}."
        end

        def unverified_summary
          @unverified.empty? ? '' : " Couldn't verify #{plural(@unverified.size, 'link')}."
        end

        def moved_summary
          @moved.empty? ? '' : " #{plural(@moved.size, 'link')} moved permanently."
        end

        def scope
          return '' unless @changed_pages

          " on #{plural(@changed_pages, 'changed page')}"
        end
      end
    end
  end
end
