# Jekyll Ruby Link Checker

[![Test](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml) [![Lint](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml) [![Package](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml) [![Coverage Status](https://coveralls.io/repos/github/dblock/jekyll-ruby-link-checker/badge.svg?branch=master)](https://coveralls.io/github/dblock/jekyll-ruby-link-checker?branch=master)

A Jekyll plugin that checks internal, anchor, and external links during the build with [ruby-link-checker](https://github.com/dblock/ruby-link-checker), and fails the build on dead links. Successful external checks are cached across builds, and a reusable GitHub Actions workflow keeps the cache between runs.

## Installation

Add the gem to your site's `Gemfile`:

```ruby
gem 'jekyll-ruby-link-checker'
```

Add it to the plugins in `_config.yml`:

```yaml
plugins:
  - jekyll-ruby-link-checker
```

## Usage

Checking is off by default, so that ordinary builds and `jekyll serve` stay fast. Set `LINK_CHECKER` to check links:

```sh
LINK_CHECKER=1 bundle exec jekyll build
```

The plugin checks the links in the content of every HTML page and document:

- internal links, against the built site, following `jekyll-redirect-from` redirect pages,
- anchors, such as `/about/#team` or `#usage`, against the `id` and `name` attributes of the target page,
- relative links, resolved against the page that contains them,
- external links, with ruby-link-checker.

It prints a summary, and fails the build listing each dead link with the pages that link to it:

```text
LinkChecker: Checked 412 internal and 2793 external links (2731 cached), skipped 25. Couldn't verify 1 link.
LinkChecker: Couldn't verify 1 link, which bot protection blocked:
https://www.linkedin.com/in/someone (HTTP 999), linked from about.md
LinkChecker: Found 2 dead links:
/missing/ (page not found), linked from _posts/2026-11-22-hello.md
https://example.org/gone (HTTP 404), linked from about.md
```

Many sites answer automated requests with HTTP 401, 403, 429, or 999, or with a Cloudflare challenge, even though the page exists. Those links are reported as unverified, with a warning and in their own section of the report, and don't fail the build. Rate-limited links are retried with exponential backoff per host first. With `permanent_redirects: true`, links that work but redirect permanently are also listed, under `## Moved Permanently` in the report, with the URL they moved to.

Links with other schemes, such as `mailto:`, aren't checked. A page or document opts out with `link_checker: false` in its front matter.

## Configuration

Configure the plugin with `link_checker` in `_config.yml`. All options are optional.

```yaml
link_checker:
  cache:
    file: .cache/link-checker.json
    ttl: 30d
    blocked_ttl: 1d
    prune: true
  exclude:
    domains: [twitter.com]
    urls: [https://example.org/flaky]
    paths: ['^/tags/']
  concurrency: 5
  retries: 1
  user_agent: My Site Link Checker
  verbose: false
  permanent_redirects: false
  blocked: [401, 403, 429, 999]
  detect_challenges: true
  timeout: 60s
  connect_timeout: 10s
  host_concurrency: 2
  host_interval: 0.5
  headers:
    Accept-Language: en-US
  host_headers:
    www.npmjs.com:
      Accept: text/html
    '/(\A|\.)medium\.com\z/':
      Cookie: consent=1
```

| Option                | Default                | Description                                                                                                                                                                             |
| ---                   | ---                    | ---                                                                                                                                                                                     |
| `cache.file`          | none                   | Cache file for successful external checks, relative to the site source. Add it to `exclude` and `.gitignore`.                                                                           |
| `cache.ttl`           | `30d`                  | How long a successful check is reused: seconds, or a number with `s`, `m`, `h`, `d`, or `w`. Failures are never cached.                                                                 |
| `cache.blocked_ttl`   | none                   | How long an unverified check is reused, so sites behind bot protection aren't requested on every build. Without it, unverified links are checked every time.                            |
| `cache.prune`         | `false`                | Remove entries of links that are no longer checked when every page is checked, so the cache doesn't keep links removed from the site. Builds that only check changed pages never prune. |
| `exclude.domains`     | `[]`                   | Hosts whose links, including subdomains, are not checked.                                                                                                                               |
| `exclude.urls`        | `[]`                   | Exact URLs that are not checked.                                                                                                                                                        |
| `exclude.paths`       | `[]`                   | Regular expressions matched against links, such as `^/tags/`.                                                                                                                           |
| `concurrency`         | `5`                    | Number of external links checked at the same time.                                                                                                                                      |
| `retries`             | `1`                    | Number of retries for a failed external check.                                                                                                                                          |
| `user_agent`          | ruby-link-checker's    | User agent sent with external checks.                                                                                                                                                   |
| `verbose`             | `false`                | Log every link and its result, and ruby-link-checker's requests.                                                                                                                        |
| `permanent_redirects` | `false`                | Also warn about, and report, working links that redirect permanently (301 or 308), with the URL to update them to. They don't fail the build.                                           |
| `blocked`             | `[401, 403, 429, 999]` | Final HTTP statuses of external links reported as unverified rather than dead; `false` reports them as dead.                                                                            |
| `detect_challenges`   | `true`                 | Also report links with a bot challenge, such as a challenge from Cloudflare, as unverified, whatever their status.                                                                      |
| `timeout`             | `60s`                  | Time limit for each external request.                                                                                                                                                   |
| `connect_timeout`     | `10s`                  | Time limit for connecting to an external host.                                                                                                                                          |
| `host_concurrency`    | unlimited              | Number of requests in flight to one host, so many links to one site don't arrive as a burst.                                                                                            |
| `host_interval`       | `0`                    | Seconds between the starts of requests to one host: a number, which can be a fraction, or a duration such as `2s`.                                                                      |
| `headers`             | none                   | Headers sent with every external request.                                                                                                                                               |
| `host_headers`        | none                   | Headers sent only to a host, by exact name or a regular expression between slashes, such as `/(\A\|\.)medium\.com\z/`, and never to the hosts it redirects to.                          |

The options from `blocked` on are passed to ruby-link-checker, and default to its defaults when they are not set; see its [documentation](https://github.com/dblock/ruby-link-checker#options). Rate-limited links are retried with exponential backoff per host. Unknown options fail the build with the list of valid options. Set `LINK_CHECKER_CACHE` to a file to use instead of `cache.file`, `LINK_CHECKER_REPORT` to a file for a Markdown report of the summary and the dead links, for example in CI, `LINK_CHECKER_FAIL=0` to log dead links as a warning instead of failing the build, and `LINK_CHECKER_CHANGED_FILES` to a file that lists changed files, one per line and relative to the site source, to only check the pages among them; a changed file that is neither a page nor a static file, such as a layout, checks all pages.

## Reusable Workflows

Two reusable workflows check links in GitHub Actions and publish the results. They're separate so that checking runs with read-only permissions, including on pull requests from forks, and publishing runs from your default branch with permission to comment, without running the checked code. Pin both to a release tag or commit.

### Checking Links

The [check-links](.github/workflows/check-links.yml) workflow builds your site with `LINK_CHECKER=1` and keeps the cache between runs, so each run only checks links that failed or weren't checked successfully within the cache's `ttl`. It restores the newest saved cache, and saves the cache even when dead links fail the build. Pull requests can restore the cache saved by the default branch.

```yaml
# .github/workflows/check-links.yml
name: Check Links

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '30 11 * * 0,3'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-links:
    uses: dblock/jekyll-ruby-link-checker/.github/workflows/check-links.yml@v0.1.0
```

| Input                | Default                    | Description                                                                                                          |
| ---                  | ---                        | ---                                                                                                                  |
| `runs-on`            | `ubuntu-latest`            | Runner label, or a JSON list of labels.                                                                              |
| `ruby-version`       | `default`                  | Ruby version, or `default` to read `.ruby-version`.                                                                  |
| `working-directory`  | `.`                        | Directory of the site.                                                                                               |
| `setup-command`      | none                       | Shell command to run in the site directory before installing Ruby and gems, for example to install system libraries. |
| `build-command`      | `bundle exec jekyll build` | Command that builds the site.                                                                                        |
| `cache-file`         | `.cache/link-checker.json` | Cache file, relative to the site directory.                                                                          |
| `cache-key-prefix`   | `link-checker-`            | Prefix of the GitHub Actions cache keys.                                                                             |
| `report-artifact`    | `link-checker-report`      | Name of the artifact that holds the report of each run, or `'false'` to skip uploading it.                           |
| `changed-files-only` | `true`                     | On pull requests, only check pages whose source changed; `false` checks all pages.                                   |
| `fail-on-dead-links` | `true`                     | Fail the check on dead links; with `false`, dead links are reported with a warning and the check passes.             |

To report dead links on pull requests without failing them, for example while the default branch has dead links of its own, pass an expression; `fail-on-dead-links` is a boolean, so it takes `true`, `false`, or an expression:

```yaml
    with:
      fail-on-dead-links: ${{ github.event_name != 'pull_request' }}
```

By default, with `changed-files-only: true`, pull requests only check the pages and documents they change, so a pull request that adds a post checks that post's links rather than the whole site. Changed static files, such as images, need no check. A pull request that changes anything else in the site, such as a layout, an include, data, `_config.yml`, or the `Gemfile`, or that deletes or renames a file, which other pages may link to, checks all pages. Other runs, such as pushes and scheduled runs, always check all pages. Set `changed-files-only: false` to check all pages on pull requests too.

The workflow inherits the caller's permissions and only needs `contents: read`. GitHub evicts caches that are not accessed for 7 days, so run the workflow at least that often, for example twice a week, to keep the cache.

Every run adds a report to its job summary, and attaches it to the run as the `link-checker-report` artifact: `link-checker-report.md`, with the summary line and a table of dead links with the reason and the pages that link to each, and, for a pull request, `link-checker-pr.txt`, with its number. Download it from the run page, or with `gh run download <run id> --name link-checker-report`. Set `report-artifact: 'false'` to skip uploading it; quote `'false'`, because inputs of reusable workflows must match their declared type, and `report-artifact` is a string.

### Publishing Results

The [publish-report](.github/workflows/publish-report.yml) workflow publishes the report of a completed run. Call it from a workflow that runs when the check completes; `workflow_run` workflows run from your default branch, with the permissions you grant them, even for pull requests from forks:

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
      issue: 'true'
```

| Input             | Default                                | Description                                                                                                                                                                     |
| ---               | ---                                    | ---                                                                                                                                                                             |
| `runs-on`         | `ubuntu-latest`                        | Runner label, or a JSON list of labels.                                                                                                                                         |
| `run-id`          | the run that triggered it, or this run | Run that uploaded the report.                                                                                                                                                   |
| `report-artifact` | `link-checker-report`                  | Name of the artifact that holds the report.                                                                                                                                     |
| `comment`         | `true`                                 | Keep a comment with the report up to date on pull requests.                                                                                                                     |
| `issue`           | `'false'`                              | On the default branch, `'true'` keeps an issue titled `Broken Links` up to date, another value is the title of the issue, and a number, such as `'123'`, is an issue by number. |

It needs `actions: read` to download the report, `pull-requests: write` to comment, and `issues: write` for the issue. It never checks out or runs the checked code, and treats the report as data.

On a pull request, it comments with the report once there are dead links, and keeps that comment up to date on later runs, including when the links are fixed. It only comments when the pull request is still at the checked commit, so a report can't be posted on another pull request.

On the default branch, with `issue`, it keeps an issue up to date:

- `issue: 'true'` uses an issue titled `Broken Links`,
- `issue: Dead Links on the Blog` uses an issue with that title,
- `issue: '123'` uses issue 123.

A run with dead links replaces the body of the issue with the report and a link to the run: an issue found by title is opened when there is no open issue with that title, and an issue given by number is reopened when it's closed. A run without dead links closes the issue with a comment. `issue` is a string, so quote `'true'`, `'false'`, and numbers. A build that fails before checking links, for example while installing gems, uploads no report and leaves the comment and the issue unchanged.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [DESIGN.md](DESIGN.md), [RELEASING.md](RELEASING.md), and [CHANGELOG.md](CHANGELOG.md).

## License

MIT License, see [LICENSE.txt](LICENSE.txt).
