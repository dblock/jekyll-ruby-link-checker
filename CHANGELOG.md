# Changelog

## 0.2.0 (Next)

- [#31](https://github.com/dblock/jekyll-ruby-link-checker/pull/31): Add screenshots of reports from code.dblock.org to the documentation - [@dblock](https://github.com/dblock).
- [#32](https://github.com/dblock/jekyll-ruby-link-checker/pull/32): Check images, in `img src` and `srcset`, and choose what's checked, where, and inside or outside the site, with `check` - [@dblock](https://github.com/dblock).
- [#33](https://github.com/dblock/jekyll-ruby-link-checker/pull/33): Check scripts and stylesheets - [@dblock](https://github.com/dblock).
- [#35](https://github.com/dblock/jekyll-ruby-link-checker/pull/35): Check what layouts and includes reference, such as navigation, once per layout, with the `layouts` option to turn it off - [@dblock](https://github.com/dblock).
- [#37](https://github.com/dblock/jekyll-ruby-link-checker/pull/37): List dead references of a kind as warnings with `fail: false`, exclude references of one kind with `exclude`, and skip anchors with `links.anchors: false` - [@dblock](https://github.com/dblock).
- [#38](https://github.com/dblock/jekyll-ruby-link-checker/pull/38): Check video, audio, and iframes, and kinds of references of your own, such as lazy-loaded images - [@dblock](https://github.com/dblock).
- [#39](https://github.com/dblock/jekyll-ruby-link-checker/pull/39): Add `rake benchmark`, which times the plugin on a generated site, or on an existing one - [@dblock](https://github.com/dblock).
- [#40](https://github.com/dblock/jekyll-ruby-link-checker/pull/40): Collect references three times faster, and only find anchors in `id` and `name` attributes - [@dblock](https://github.com/dblock).
- [#41](https://github.com/dblock/jekyll-ruby-link-checker/pull/41): List features in `README.md`, and simplify the documentation - [@dblock](https://github.com/dblock).
- [#42](https://github.com/dblock/jekyll-ruby-link-checker/pull/42): Only fail on new dead links with `LINK_CHECKER_FAIL=new`, compared with the dead links of an earlier build in `LINK_CHECKER_BASELINE`, which `LINK_CHECKER_DEAD_LINKS` writes - [@dblock](https://github.com/dblock).
- Your contribution here.

## 0.1.0 (2026/11/23)

- [#2](https://github.com/dblock/jekyll-ruby-link-checker/pull/2): Check internal, anchor, relative, and external links during the build, with configuration, a persistent cache, and a reusable workflow that keeps the cache between runs - [@dblock](https://github.com/dblock).
- [#3](https://github.com/dblock/jekyll-ruby-link-checker/pull/3): Release with ruby-gem-release from a manually dispatched workflow, with RubyGems Trusted Publishing - [@dblock](https://github.com/dblock).
- [#4](https://github.com/dblock/jekyll-ruby-link-checker/pull/4): Write a Markdown report of dead links to `LINK_CHECKER_REPORT`, add it to the job summary of the reusable workflow, and optionally keep an issue with the dead links up to date - [@dblock](https://github.com/dblock).
- [#6](https://github.com/dblock/jekyll-ruby-link-checker/pull/6): Attach the link checker report to each run of the reusable workflow as an artifact - [@dblock](https://github.com/dblock).
- [#7](https://github.com/dblock/jekyll-ruby-link-checker/pull/7): Combine the `issue` and `issue-title` workflow inputs into `issue`, which takes `'true'`, a title, or an issue number - [@dblock](https://github.com/dblock).
- [#9](https://github.com/dblock/jekyll-ruby-link-checker/pull/9): Publish results with a separate reusable workflow that comments on pull requests and keeps the issue up to date from `workflow_run`, so links can be checked on pull requests from forks with read-only permissions - [@dblock](https://github.com/dblock).
- [#10](https://github.com/dblock/jekyll-ruby-link-checker/pull/10): Add `LINK_CHECKER_FAIL` and the `fail-on-dead-links` workflow input to report dead links without failing the build, for example on pull requests - [@dblock](https://github.com/dblock).
- [#11](https://github.com/dblock/jekyll-ruby-link-checker/pull/11): Add `LINK_CHECKER_CHANGED_FILES` and the `changed-files-only` workflow input, on by default, to only check the pages a pull request changes - [@dblock](https://github.com/dblock).
- [#14](https://github.com/dblock/jekyll-ruby-link-checker/pull/14): Fix reporting redirects and a failed HEAD before GET as dead links - [@dblock](https://github.com/dblock).
- [#15](https://github.com/dblock/jekyll-ruby-link-checker/pull/15): Upgrade to ruby-link-checker 0.6, report links blocked by bot protection as unverified without failing the build, and use ruby-link-checker's reasons - [@dblock](https://github.com/dblock).
- [#16](https://github.com/dblock/jekyll-ruby-link-checker/pull/16): Add the `blocked`, `detect_challenges`, `timeout`, `connect_timeout`, `host_concurrency`, `host_interval`, `headers`, and `host_headers` options - [@dblock](https://github.com/dblock).
- [#18](https://github.com/dblock/jekyll-ruby-link-checker/pull/18): Add the `cache.blocked_ttl` and `cache.prune` options - [@dblock](https://github.com/dblock).
- [#19](https://github.com/dblock/jekyll-ruby-link-checker/pull/19): Add the `permanent_redirects` option to report links that moved permanently, with the URL to update them to - [@dblock](https://github.com/dblock).
- [#20](https://github.com/dblock/jekyll-ruby-link-checker/pull/20): Keep the existing cache of a site at the repository root when switching to the reusable workflow, by caching the bare `cache-file` path - [@dblock](https://github.com/dblock).
- [#21](https://github.com/dblock/jekyll-ruby-link-checker/pull/21): Simplify the documentation - [@dblock](https://github.com/dblock).
- [#22](https://github.com/dblock/jekyll-ruby-link-checker/pull/22): Add a logo - [@dblock](https://github.com/dblock).
- [#23](https://github.com/dblock/jekyll-ruby-link-checker/pull/23): Accept regular expressions between slashes in `exclude.urls` - [@dblock](https://github.com/dblock).
- [#24](https://github.com/dblock/jekyll-ruby-link-checker/pull/24): List links in the report with the titles of the pages that link to them, instead of tables - [@dblock](https://github.com/dblock).
- [#25](https://github.com/dblock/jekyll-ruby-link-checker/pull/25): Group unverified links by site in the report, and collapse them - [@dblock](https://github.com/dblock).
- [#27](https://github.com/dblock/jekyll-ruby-link-checker/pull/27): Move the usage, configuration, and GitHub Actions documentation to `docs/`, add a guide to fixing links, linked from the report, and update the workflow version pins in the documentation on release - [@dblock](https://github.com/dblock).
- [#28](https://github.com/dblock/jekyll-ruby-link-checker/pull/28): Add the check as an action, `action.yml`, for GitHub Marketplace - [@dblock](https://github.com/dblock).
- [#29](https://github.com/dblock/jekyll-ruby-link-checker/pull/29): Suggest `exclude` settings for unverified links and sites that didn't answer properly in the report - [@dblock](https://github.com/dblock).
- [#30](https://github.com/dblock/jekyll-ruby-link-checker/pull/30): Post Danger comments on stacked pull requests - [@dblock](https://github.com/dblock).
