# Design

This plugin checks the links in a Jekyll site while it builds and fails the build when a link is dead. It replaces copies of `_plugins/link-checker.rb` in [code.dblock.org](https://github.com/dblock/code.dblock.org) and the [OpenSearch documentation](https://github.com/opensearch-project/documentation-website), and adds configuration, a persistent cache, and a reusable GitHub Actions workflow.

## Scope

The first version will:

- Collect every `<a href>` from rendered pages and documents, skipping assets such as CSS and JavaScript.
- Check external links with [ruby-link-checker](https://github.com/dblock/ruby-link-checker) and its Typhoeus checker, with configurable concurrency, retries, and user agent.
- Check internal links and anchors against the built site, following `jekyll-redirect-from` redirect pages.
- Skip configured domains, URLs, and paths.
- Reuse successful external checks for a configurable time with ruby-link-checker's persistent cache. Failures are never cached, so dead links are always checked again.
- Fail the build with every dead link and the pages that link to it.
- Provide a reusable workflow that restores the cache, builds the site, and saves the cache, even when the build fails on dead links.

It will not check images or scripts, support generators other than Jekyll, change ruby-link-checker, fix links, or open issues; [html-proofer](https://github.com/gjtorikian/html-proofer) checks built HTML more broadly, and the calling workflow decides what to do with a failure.

## Configuration

Configuration lives in `link_checker` in `_config.yml`. The `LINK_CHECKER` environment variable turns checking on, so that ordinary builds and `jekyll serve` stay fast.

```yaml
link_checker:
  cache:
    file: .cache/link-checker.json
    ttl: 30d
  exclude:
    domains: [example.com]
    urls: [https://example.org/flaky]
    paths: ['^/tags', '^mailto:']
  concurrency: 5
  retries: 1
  user_agent: My Site Link Checker
  verbose: false
```

A page or document opts out with `link_checker: false` in front matter. Unknown options fail the build with the list of valid options. The plugin logs a summary by default, and each checked link, including cache hits, only with `verbose: true`.

## Reusable Workflow

`.github/workflows/check-links.yml` will be callable with `workflow_call`. It checks out the calling repository, installs optional system packages, sets up Ruby with Bundler caching, restores the newest cache saved under a key prefix, runs the build with `LINK_CHECKER=1`, and saves the cache under a key unique to the run and attempt. GitHub caches cannot be overwritten, so each run saves a new key and the next run restores the newest one through the prefix. The save runs even when the build fails, because ruby-link-checker writes the cache as each check succeeds.

## Lessons from `jekyll-og-image`

[jekyll-og-image](https://github.com/igor-alexandrov/jekyll-og-image) is a well-structured Jekyll plugin that this design borrows from: configuration sections that reject unknown options with the valid ones, front matter overrides per document, correct behavior under `jekyll serve`, and tests that build small fixture sites. This project also logs quietly by default, keeps a changelog and contributor documentation from the start, and tests only Ruby versions that CI can install.
