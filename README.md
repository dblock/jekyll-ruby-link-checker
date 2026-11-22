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
LinkChecker: Checked 412 internal and 2793 external links (2731 cached), skipped 25.
LinkChecker: Found 2 dead links:
/missing/ (page not found), linked from _posts/2026-11-22-hello.md
https://example.org/gone (HTTP 404), linked from about.md
```

Links with other schemes, such as `mailto:`, aren't checked. A page or document opts out with `link_checker: false` in its front matter.

## Configuration

Configure the plugin with `link_checker` in `_config.yml`. All options are optional.

```yaml
link_checker:
  cache:
    file: .cache/link-checker.json
    ttl: 30d
  exclude:
    domains: [twitter.com]
    urls: [https://example.org/flaky]
    paths: ['^/tags/']
  concurrency: 5
  retries: 1
  user_agent: My Site Link Checker
  verbose: false
```

| Option            | Default             | Description                                                                                                             |
| ---               | ---                 | ---                                                                                                                     |
| `cache.file`      | none                | Cache file for successful external checks, relative to the site source. Add it to `exclude` and `.gitignore`.           |
| `cache.ttl`       | `30d`               | How long a successful check is reused: seconds, or a number with `s`, `m`, `h`, `d`, or `w`. Failures are never cached. |
| `exclude.domains` | `[]`                | Hosts whose links, including subdomains, are not checked.                                                               |
| `exclude.urls`    | `[]`                | Exact URLs that are not checked.                                                                                        |
| `exclude.paths`   | `[]`                | Regular expressions matched against links, such as `^/tags/`.                                                           |
| `concurrency`     | `5`                 | Number of external links checked at the same time.                                                                      |
| `retries`         | `1`                 | Number of retries for a failed external check.                                                                          |
| `user_agent`      | ruby-link-checker's | User agent sent with external checks.                                                                                   |
| `verbose`         | `false`             | Log every link and its result, and ruby-link-checker's requests.                                                        |

Unknown options fail the build with the list of valid options. Set `LINK_CHECKER_CACHE` to a file to use instead of `cache.file`, and `LINK_CHECKER_REPORT` to a file for a Markdown report of the summary and the dead links, for example in CI.

## Reusable Workflow

The [check-links](.github/workflows/check-links.yml) workflow builds your site with `LINK_CHECKER=1` and keeps the cache between runs, so each run only checks links that failed or weren't checked successfully within the cache's `ttl`. It restores the newest saved cache, and saves the cache even when dead links fail the build. Pin it to a release tag or commit:

```yaml
name: Check Links

on:
  push:
    branches: [main]
  schedule:
    - cron: '30 11 * * 0,3'
  workflow_dispatch:

permissions:
  contents: read
  issues: write

jobs:
  check-links:
    uses: dblock/jekyll-ruby-link-checker/.github/workflows/check-links.yml@v0.1.0
    with:
      issue: true
```

| Input               | Default                    | Description                                                                                                          |
| ---                 | ---                        | ---                                                                                                                  |
| `runs-on`           | `ubuntu-latest`            | Runner label, or a JSON list of labels.                                                                              |
| `ruby-version`      | `default`                  | Ruby version, or `default` to read `.ruby-version`.                                                                  |
| `working-directory` | `.`                        | Directory of the site.                                                                                               |
| `setup-command`     | none                       | Shell command to run in the site directory before installing Ruby and gems, for example to install system libraries. |
| `build-command`     | `bundle exec jekyll build` | Command that builds the site.                                                                                        |
| `cache-file`        | `.cache/link-checker.json` | Cache file, relative to the site directory.                                                                          |
| `cache-key-prefix`  | `link-checker-`            | Prefix of the GitHub Actions cache keys.                                                                             |
| `report-artifact`   | `link-checker-report`      | Name of the artifact that holds the report of each run, or `'false'` to skip uploading it.                           |
| `issue`             | `false`                    | Keep an open issue with the dead links up to date, and close it when all links work.                                 |
| `issue-title`       | `Broken Links`             | Title of the issue.                                                                                                  |

The workflow inherits the caller's permissions: grant `contents: read`, and also `issues: write` with `issue: true`. GitHub evicts caches that are not accessed for 7 days, so run the workflow at least that often, for example twice a week, to keep the cache.

### Publishing Results

Every run adds a report to its job summary, and attaches it to the run as the `link-checker-report` artifact, a `link-checker-report.md` file: the summary line, and a table of dead links with the reason and the pages that link to each. Download it from the run page, or with `gh run download <run id> --name link-checker-report`. Set `report-artifact: 'false'` to skip uploading it; quote `'false'`, because inputs of reusable workflows must match their declared type, and `report-artifact` is a string.

With `issue: true`, the workflow also keeps one open issue, titled `issue-title`, up to date. A run with dead links opens the issue, or replaces the body of the open one, with the report and a link to the run. A run without dead links closes the open issue with a comment. A build that fails before checking links, for example while installing gems, leaves the issue unchanged. To act on a failure in another way, add a job that `needs: check-links` with `if: failure()`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [DESIGN.md](DESIGN.md), [RELEASING.md](RELEASING.md), and [CHANGELOG.md](CHANGELOG.md).

## License

MIT License, see [LICENSE.txt](LICENSE.txt).
