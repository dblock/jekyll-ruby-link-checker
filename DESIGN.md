# Design

This plugin checks the links in a Jekyll site while it builds and fails the build when a link is dead. It replaces copies of `_plugins/link-checker.rb` in [code.dblock.org](https://github.com/dblock/code.dblock.org) and the [OpenSearch documentation](https://github.com/opensearch-project/documentation-website), and adds configuration, a persistent cache, and a reusable GitHub Actions workflow.

## Scope

The first version:

- Collects every `<a href>` from the rendered content of HTML pages and documents.
- Checks external links with [ruby-link-checker](https://github.com/dblock/ruby-link-checker) and its Typhoeus checker, with configurable concurrency, retries, and user agent.
- Checks internal links and anchors against the built site, following `jekyll-redirect-from` redirect pages. A path without an extension is a directory index or a page served without its `.html` extension, and relative links are resolved against the page that contains them.
- Skips links with schemes other than `http` and `https`, and configured domains, URLs, and paths.
- Reuses successful external checks for a configurable time with ruby-link-checker's persistent cache. Failures are never cached, so dead links are always checked again.
- Fails the build with every dead link and the pages that link to it.
- Provides a reusable workflow that restores the cache, builds the site, and saves the cache, even when the build fails on dead links.

It does not check images or scripts, support generators other than Jekyll, change ruby-link-checker, fix links, or open issues; [html-proofer](https://github.com/gjtorikian/html-proofer) checks built HTML more broadly, and the calling workflow decides what to do with a failure.

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

## Implementation

Hooks in `hooks.rb` start a `Checker` before rendering when `LINK_CHECKER` is set, collect links from each page and document after it renders, and check them after the site is written, when internal targets exist on disk. `Configuration` validates options, `Urls` resolves relative links, turns absolute links to the site into paths, and applies exclusions, `InternalLinks` checks the built files, and `Report` counts links and raises `DeadLinksError`. ruby-link-checker reports cache hits when a link is queued, before the checker runs, so the result callback is registered before links are queued.

## Reusable Workflow

`.github/workflows/check-links.yml` is callable with `workflow_call`. It runs on a configurable runner, checks out the calling repository, runs an optional setup command, such as installing system libraries for native gems, sets up Ruby with Bundler caching, restores the newest cache saved under a key prefix, runs the build with `LINK_CHECKER=1` and `LINK_CHECKER_CACHE` pointing at the cache file, and saves the cache under a key unique to the run and attempt. GitHub caches cannot be overwritten, so each run saves a new key and the next run restores the newest one through the prefix. The save runs even when the build fails, because ruby-link-checker writes the cache as each check succeeds.

The build writes a Markdown report to `LINK_CHECKER_REPORT`, starting with an HTML comment that holds the number of dead links, so the workflow doesn't parse prose. The workflow adds the report to the job summary and uploads it as an artifact of the run, even when the build fails. With `issue`, it uses an issue given by number, or the open issue with the exact title (`Broken Links` for `'true'`); it edits the issue, opening one by title or reopening one by number, while links are dead, and closes it when they all work; without a report, the build failed before checking links, and the issue is left alone. The workflow declares no permissions and inherits the caller's, because a reusable workflow cannot request more than its caller grants: callers that don't use the issue don't need `issues: write`. `issue` is a string input, so it can take `'true'`, a title, or a number; callers quote `'true'` and numbers, because inputs must match their declared type.

## Lessons from `jekyll-og-image`

[jekyll-og-image](https://github.com/igor-alexandrov/jekyll-og-image) is a well-structured Jekyll plugin that this design borrows from: configuration sections that reject unknown options with the valid ones, front matter overrides per document, correct behavior under `jekyll serve`, and tests that build small fixture sites. This project also logs quietly by default, keeps a changelog and contributor documentation from the start, and tests only Ruby versions that CI can install.
