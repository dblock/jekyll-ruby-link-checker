<img alt="jekyll-ruby-link-checker" src="assets/logo.svg" width="128">

# Jekyll Ruby Link Checker

[![Test](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml) [![Lint](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml) [![Package](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml) [![Coverage Status](https://coveralls.io/repos/github/dblock/jekyll-ruby-link-checker/badge.svg?branch=master)](https://coveralls.io/github/dblock/jekyll-ruby-link-checker?branch=master)

A Jekyll plugin that checks the links in your site while it builds, and fails the build when a link is dead. It uses [ruby-link-checker](https://github.com/dblock/ruby-link-checker) for external links and remembers the ones that worked, so later builds are fast. It also comes with GitHub Actions workflows that check links on every push and pull request.

## Installation

Add the gem to your `Gemfile`:

```ruby
gem 'jekyll-ruby-link-checker'
```

And to the plugins in `_config.yml`:

```yaml
plugins:
  - jekyll-ruby-link-checker
```

## Usage

Checking is off by default, so that `jekyll serve` stays fast. Turn it on with `LINK_CHECKER`:

```sh
LINK_CHECKER=1 bundle exec jekyll build
```

The plugin checks every link in your pages and posts: links to other pages of the site, anchors such as `#usage`, relative links, and links to other sites. It prints a summary, and fails the build if it finds dead links, saying where each one is linked from:

```text
LinkChecker: Checked 412 internal and 2793 external links (2731 cached), skipped 25. Couldn't verify 1 link.
LinkChecker: Couldn't verify 1 link, which bot protection blocked:
https://www.linkedin.com/in/someone (HTTP 999), linked from about.md
LinkChecker: Found 2 dead links:
/missing/ (page not found), linked from _posts/2026-11-22-hello.md
https://example.org/gone (HTTP 404), linked from about.md
```

Many sites block automated requests, for example with a 403 or a Cloudflare challenge, even when the page exists. Those links are reported as unverified, and don't fail the build.

To skip a page, add `link_checker: false` to its front matter.

## Configuration

Configure the plugin with `link_checker` in `_config.yml`. Every option is optional; the values below are examples, and the comments give the defaults.

```yaml
link_checker:
  cache:
    file: .cache/link-checker.json # where to remember links that worked; add it to .gitignore (default: none)
    ttl: 30d                       # how long to remember them (default: 30d)
    blocked_ttl: 1d                # how long to remember unverified links (default: check them every time)
    prune: true                    # forget links that are no longer on the site (default: false)
  exclude:
    domains: [twitter.com]         # sites never to check, including their subdomains
    urls: [https://example.org/flaky]
    paths: ['^/tags/']             # regular expressions
  concurrency: 5                   # links checked at the same time (default: 5)
  retries: 1                       # retries of a failed link (default: 1)
  user_agent: My Site Link Checker
  verbose: false                   # log every link (default: false)
  permanent_redirects: false       # also list links that moved permanently, with their new URL (default: false)
  blocked: [401, 403, 429, 999]    # statuses reported as unverified; false reports them as dead
  detect_challenges: true          # report bot challenges, such as Cloudflare's, as unverified (default: true)
  timeout: 60s                     # time limit for each request (default: 60s)
  connect_timeout: 10s             # time limit for connecting (default: 10s)
  host_concurrency: 2              # requests at the same time to one site (default: unlimited)
  host_interval: 0.5               # seconds between requests to one site (default: 0)
  headers:                         # headers sent to every site
    Accept-Language: en-US
  host_headers:                    # headers sent to one site, by name or /regular expression/
    www.npmjs.com:
      Accept: text/html
    '/(\A|\.)medium\.com\z/':
      Cookie: consent=1
```

A duration is a number of seconds, or a number followed by `s`, `m`, `h`, `d`, or `w`. Dead links are never remembered, so they're checked again on every build. Pruning only happens when every page is checked. The options from `blocked` down are passed to ruby-link-checker; see its [documentation](https://github.com/dblock/ruby-link-checker#options) for details. Misspelled options fail the build with the list of valid ones.

A few environment variables change how a build checks links, mostly for CI:

```sh
LINK_CHECKER_CACHE=path/to/cache.json # use this cache file instead of cache.file
LINK_CHECKER_REPORT=report.md         # also write a report in Markdown
LINK_CHECKER_FAIL=0                   # warn about dead links instead of failing the build
LINK_CHECKER_CHANGED_FILES=files.txt  # only check the pages listed in this file, one per line
```

With `LINK_CHECKER_CHANGED_FILES`, a change to a layout, an include, or anything else that isn't a page or an image checks every page.

## GitHub Actions

Two reusable workflows check links in GitHub Actions. One checks links and only needs to read your repository, so it's safe to run on pull requests from forks. The other runs after it to comment on pull requests and keep an issue up to date.

### Checking Links

[`check-links.yml`](.github/workflows/check-links.yml) builds your site with link checking on. It keeps the cache between runs, so each run only checks links that it hasn't checked recently. Every run adds a report to its summary and attaches it to the run.

```yaml
# .github/workflows/check-links.yml
name: Check Links

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '30 11 * * 0,3' # GitHub deletes caches that aren't used for a week
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-links:
    uses: dblock/jekyll-ruby-link-checker/.github/workflows/check-links.yml@v0.1.0
    with:
      ruby-version: '3.4'                           # default: read .ruby-version
      working-directory: .                          # where the site is (default: .)
      setup-command: sudo apt-get install -y libvips # runs before installing gems (default: none)
      build-command: bundle exec jekyll build       # (default: bundle exec jekyll build)
      cache-file: .cache/link-checker.json          # relative to the site (default: .cache/link-checker.json)
      cache-key-prefix: link-checker-               # (default: link-checker-)
      report-artifact: link-checker-report          # name of the report, or 'false' (default: link-checker-report)
      changed-files-only: true                      # pull requests only check the pages they change (default: true)
      fail-on-dead-links: ${{ github.event_name != 'pull_request' }} # (default: true)
      runs-on: ubuntu-latest                        # a runner label, or a JSON list (default: ubuntu-latest)
```

Pull requests only check the pages they change, so a pull request that adds a post checks that post. A pull request that changes a layout, `_config.yml`, the `Gemfile`, or anything else that affects every page, or that deletes or renames a file, checks every page. Pushes and scheduled runs always check every page.

The `fail-on-dead-links` example above fails on dead links everywhere except pull requests, which is useful while the site still has dead links of its own.

Inputs of reusable workflows must match their type, so quote `'false'` for `report-artifact`, which takes a name.

### Publishing Results

[`publish-report.yml`](.github/workflows/publish-report.yml) reads the report of a completed check. On a pull request, it comments with the dead links and keeps that comment up to date. On your default branch, it can keep an issue up to date: it opens the issue when there are dead links, updates it, and closes it when they're fixed. It never runs the code it checked, so it can safely comment on pull requests from forks.

```yaml
# .github/workflows/publish-link-checker-report.yml
name: Publish Link Checker Report

on:
  workflow_run:
    workflows: [Check Links]
    types: [completed]

permissions:
  actions: read
  issues: write
  pull-requests: write

jobs:
  publish:
    uses: dblock/jekyll-ruby-link-checker/.github/workflows/publish-report.yml@v0.1.0
    with:
      issue: 'true'          # 'true' for an issue titled Broken Links, a title, a number such as '123', or 'false' (default: 'false')
      comment: true          # comment on pull requests (default: true)
      runs-on: ubuntu-latest # (default: ubuntu-latest)
```

Quote `'true'`, `'false'`, and issue numbers, because `issue` takes text.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [DESIGN.md](DESIGN.md), [RELEASING.md](RELEASING.md), and [CHANGELOG.md](CHANGELOG.md).

## License

MIT License, see [LICENSE.txt](LICENSE.txt).
