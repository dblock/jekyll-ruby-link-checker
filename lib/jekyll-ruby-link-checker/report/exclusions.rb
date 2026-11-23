# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Report
      # Suggests `exclude` settings for links whose result may not be the same on the next run: unverified links, by
      # site when a site has several, and dead links that failed because the site didn't answer properly. Pages that
      # are gone are left out, because they need to be fixed.
      module Exclusions
        FLAKY = /\A(?:\w+: )?(?:HTTP 5\d\d|Timeout|Connection error)/
        EXCLUSIONS = "These links may work, but couldn't be checked reliably. After checking them in a browser, " \
                     'add this to `_config.yml` to stop checking them.'

        def exclusions_section
          domains, urls = suggested_exclusions
          return [] if domains.empty? && urls.empty?

          ['### Suggested Exclusions', '', EXCLUSIONS, '', '<details><summary>_config.yml</summary>', '',
           '```yaml', *exclusions_yaml(domains, urls), '```', '', '</details>']
        end

        private

        def exclusions_yaml(domains, urls)
          ['link_checker:', '  exclude:',
           *yaml_list('domains', domains.map { |host, count| "#{host} # #{plural(count, 'unverified link')}" }),
           *yaml_list('urls', urls.map { |url, reason| "'#{url.gsub("'", "''")}' # #{reason}" })]
        end

        def yaml_list(name, items)
          items.empty? ? [] : ["    #{name}:", *items.map { |item| "      - #{item}" }]
        end

        # Sites with several unverified links, by how many, and other unverified and flaky links, with their reason.
        def suggested_exclusions
          several, single = unverified_sites.partition { |_host, links| links.size > 1 }
          urls = (single.flat_map(&:last) + flaky_failures).map { |url, link| [url, link[:reason]] }
          [site_counts(several), urls.sort]
        end

        def unverified_sites
          @unverified.group_by { |url, _link| URI(url).host }
        end

        def site_counts(sites)
          sites.map { |host, links| [host, links.size] }.sort_by { |host, count| [-count, host] }
        end

        def flaky_failures
          (@dead || @failures).select { |url, link| url.match?(%r{\Ahttps?://}) && link[:reason].match?(FLAKY) }.to_a
        end
      end
    end
  end
end
