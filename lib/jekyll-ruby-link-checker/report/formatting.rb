# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # Text of the summary, the log messages, and the Markdown report.
      module Formatting
        # A Markdown report starts with this marker, so a workflow can read the number of dead links.
        MARKER = 'jekyll-ruby-link-checker dead links:'
        UNVERIFIED = 'Bot protection blocked these checks, so these links may work. Check them in a browser.'
        MOVED = 'These links work, but redirect permanently. Update them to link to where they moved.'

        def summary
          "Checked #{@counts[:internal]} internal and #{@counts[:external]} external links " \
            "(#{@counts[:cached]} cached)#{scope}, skipped #{@counts[:excluded]}.#{unverified_summary}#{moved_summary}"
        end

        def markdown
          lines = ["<!-- #{MARKER} #{@failures.size} -->", '', summary, '']
          lines += @failures.empty? ? ['No dead links.'] : table(@failures)
          lines += ['', '## Unverified Links', '', UNVERIFIED, '', *table(@unverified)] unless @unverified.empty?
          lines += ['', '## Moved Permanently', '', MOVED, '', *table(@moved, 'Moved To')] unless @moved.empty?
          "#{lines.join("\n")}\n"
        end

        def message
          "Found #{plural(@failures.size, 'dead link')}:\n#{list(@failures)}"
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

        def table(links, reason = 'Reason')
          ["| Link | #{reason} | Linked From |", '| --- | --- | --- |', *rows(links)]
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
end
