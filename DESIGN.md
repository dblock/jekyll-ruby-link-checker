# Design

This plugin checks the links in a Jekyll site while it builds and fails the build when a link is dead. It replaces copies of `_plugins/link-checker.rb` in [code.dblock.org](https://github.com/dblock/code.dblock.org) and the [OpenSearch documentation](https://github.com/opensearch-project/documentation-website), and adds configuration, a persistent cache, and a reusable GitHub Actions workflow.

## Scope

The first version:

- Collects every `<a href>` from the rendered content of HTML pages and documents.
- Checks external links with [ruby-link-checker](https://github.com/dblock/ruby-link-checker) and its Typhoeus checker, with configurable concurrency, retries, and user agent, and ruby-link-checker's options for blocked statuses, challenge detection, timeouts, limits per host, and headers. Those options are only passed when they are set, so they keep ruby-link-checker's defaults, and their names describe the site (`host_concurrency`) rather than mirror ruby-link-checker's (`max_concurrency_per_host`). YAML can't hold a Ruby `Regexp`, so `host_headers` reads a host between slashes as a regular expression.
- Checks internal links and anchors against the built site, following `jekyll-redirect-from` redirect pages. A path without an extension is a directory index or a page served without its `.html` extension, and relative links are resolved against the page that contains them.
- Skips links with schemes other than `http` and `https`, and configured domains, URLs, and paths.
- Reuses successful external checks for a configurable time with ruby-link-checker's persistent cache. Failures are never cached, so dead links are always checked again. Unverified checks are only reused with `cache.blocked_ttl`, which is meant to be shorter. With `cache.prune`, ruby-link-checker removes the entries that a build didn't use, but only when the build checks every page: a build with `LINK_CHECKER_CHANGED_FILES` would otherwise remove the entries of the links on the pages it skipped.
- Reports links that ruby-link-checker classifies as blocked by bot protection, by status (401, 403, 429, 999) or by a detected challenge, as unverified: they're listed separately, with ruby-link-checker's reason, and don't fail the build, because the page behind a bot wall usually exists. Results are recorded from ruby-link-checker's `complete` event, which fires once per link with its final result, not from `result`, which fires for every attempt, including each redirect.
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

Dead links fail the build with `DeadLinksError` unless `LINK_CHECKER_FAIL` is off, in which case they're logged as a warning; the report is the same either way. Reporting without failing lives in the gem rather than in the workflow, with `continue-on-error`, so a build that fails for another reason still fails. The workflow's `fail-on-dead-links` input sets it, and the job summary step adds a warning annotation when there are dead links.

`LINK_CHECKER_CHANGED_FILES` lists the files a change touched, and the checker then only collects links from the pages and documents among them, matched by their source path. The whole site is still built, so links from changed pages to unchanged ones resolve. Static files are skipped, because the checker only reads links in pages, and any other changed file can change every page, so it falls back to checking all of them, as it does when nothing says what changed. The workflow lists changed files with `git diff HEAD^1 HEAD`: `actions/checkout` checks out the merge commit of a pull request, whose first parent is the base branch, so a checkout two commits deep holds exactly the pull request's change, without the GitHub API or the full history. Deleted and renamed files fall back to checking all pages, because unchanged pages may link to them.

The build writes a Markdown report to `LINK_CHECKER_REPORT`, starting with an HTML comment that holds the number of dead links, so workflows don't parse prose. The workflow adds the report to the job summary and uploads it as an artifact of the run, even when the build fails, with the pull request number for pull requests.

## Publishing Results

Publishing is a separate reusable workflow, `.github/workflows/publish-report.yml`, because pull requests from forks get a read-only token, and running their code with permission to write would be unsafe. Callers trigger it with `workflow_run` when the check completes; it runs from the default branch with the permissions the caller grants, downloads the report from the completed run, and never checks out or runs the checked code. It defaults to the triggering run, or the current run, so it can also run in the same workflow after the check, as the Integration workflow does.

On a pull request, it keeps one comment, found by a hidden marker, up to date, and only creates it once there are dead links. It trusts the pull request number in the artifact only when that pull request is still at the commit that was checked, so a run can't comment on another pull request. On the default branch, outside pull requests, `issue` keeps an issue up to date: it uses an issue given by number, or the open issue with the exact title (`Broken Links` for `'true'`); it edits the issue, opening one by title or reopening one by number, while links are dead, and closes it when they all work. Without a report, the build failed before checking links, and the comment and issue are left alone.

Neither workflow declares permissions; jobs inherit the caller's, because a reusable workflow cannot request more than its caller grants. `issue` is a string input, so it can take `'true'`, a title, or a number; callers quote `'true'` and numbers, because inputs must match their declared type.

## Lessons from `jekyll-og-image`

[jekyll-og-image](https://github.com/igor-alexandrov/jekyll-og-image) is a well-structured Jekyll plugin that this design borrows from: configuration sections that reject unknown options with the valid ones, front matter overrides per document, correct behavior under `jekyll serve`, and tests that build small fixture sites. This project also logs quietly by default, keeps a changelog and contributor documentation from the start, and tests only Ruby versions that CI can install.
