# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # The Markdown report: lists of links with the pages that link to them, by title, which read better than tables
      # of long URLs and source paths in issues, comments, and job summaries.
      module Markdown
        # A Markdown report starts with this marker, so a workflow can read the number of dead links.
        MARKER = 'jekyll-ruby-link-checker dead links:'
        UNVERIFIED = 'Bot protection blocked these checks, so these links may work. Check them in a browser.'
        MOVED = 'These links work, but redirect permanently. Update them to link to where they moved.'
        # Pages listed under a link before the rest are collapsed.
        PAGES_SHOWN = 3
        # Longest link text before it's shortened.
        TEXT_LENGTH = 60

        def markdown
          lines = ["<!-- #{MARKER} #{@failures.size} -->", '', summary, '']
          lines += @failures.empty? ? ['No dead links.'] : section(@failures, 'Dead Link')
          lines += ['', *unverified_section] unless @unverified.empty?
          lines += ['', *section(@moved, 'Link', MOVED, moved: true)] unless @moved.empty?
          "#{lines.join("\n")}\n"
        end

        private

        def section(links, noun, note = nil, moved: false)
          title = moved ? "#{plural(links.size, noun)} Moved Permanently" : plural(links.size, noun)
          ["### #{title}", '', *([note, ''] if note), *links.sort.flat_map { |url, link| item(url, link, moved) }]
        end

        # Unverified links often outnumber dead ones and come from a few sites, so they're grouped by site and
        # collapsed. A link is only blocked after a server answered, so it has a host.
        def unverified_section
          sites = @unverified.group_by { |url, _link| URI(url).host }.sort_by { |name, links| [-links.size, name] }
          ["### #{plural(@unverified.size, 'Unverified Link')}", '', UNVERIFIED, '',
           "<details><summary>#{plural(sites.size, 'site')}</summary>", '',
           *sites.flat_map { |name, links| site(name, links) }, '', '</details>']
        end

        def site(name, links)
          reasons = links.map { |_url, link| link[:reason] }.uniq.sort.map { |reason| escape(reason) }.join(', ')
          ["- #{escape(name)}: #{plural(links.size, 'link')}, #{reasons}",
           *links.sort.map { |url, _link| "  - #{link_to(url)}" }]
        end

        def item(url, link, moved)
          detail = moved ? "moved to #{link_to(link[:reason])}" : "(#{escape(link[:reason])})"
          ["- #{link_to(url)} #{detail}", *pages(link[:locations])]
        end

        def pages(locations)
          links = locations.map { |location| page_link(location) }.sort_by(&:downcase)
          shown = links.first(PAGES_SHOWN).map { |page| "  - #{page}" }
          rest = links.drop(PAGES_SHOWN)
          return shown if rest.empty?

          shown + ["  - <details><summary>#{plural(rest.size, 'more page')}</summary>", '',
                   *rest.map { |page| "    - #{page}" }, '', '    </details>']
        end

        # Every location is a page that the checker recorded.
        def page_link(location)
          page = @pages.fetch(location)
          text = escape(page[:title] || location)
          page[:url] ? "[#{text}](<#{page[:url]}>)" : text
        end

        # Shows a link without its scheme and shortened, and links to all of it; paths link to the site, when known.
        # A trailing slash is kept, so that two links that differ only by one don't look the same.
        def link_to(url)
          href = url.start_with?('/') && @site_url ? "#{@site_url}#{url}" : url
          text = escape(shorten(url))
          href.match?(%r{\Ahttps?://}) ? "[#{text}](<#{href}>)" : text
        end

        def shorten(url)
          text = url.sub(%r{\Ahttps?://}, '')
          text.length > TEXT_LENGTH ? "#{text[0, TEXT_LENGTH - 1]}…" : text
        end

        def escape(text)
          text.to_s.gsub(/[\\`*_\[\]<>|]/) { |char| "\\#{char}" }
        end
      end
    end
  end
end
