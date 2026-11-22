# Changelog

## 0.1.0 (Next)

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
- Your contribution here.
