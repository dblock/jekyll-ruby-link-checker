<img alt="jekyll-ruby-link-checker" src="assets/logo.svg" width="128">

# Jekyll Ruby Link Checker

[![Test](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/test.yml) [![Lint](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/lint.yml) [![Package](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/jekyll-ruby-link-checker/actions/workflows/package.yml) [![Coverage Status](https://coveralls.io/repos/github/dblock/jekyll-ruby-link-checker/badge.svg?branch=master)](https://coveralls.io/github/dblock/jekyll-ruby-link-checker?branch=master)

A Jekyll plugin that checks the links, images, and other references of your site while it builds, and fails the build when one is dead. It comes with GitHub Actions workflows that check links on every push and pull request.

## Features

- Checks links to pages of your site, anchors such as `#usage`, relative links, and links to other sites.
- Also checks images, including `srcset` and `<picture>`, scripts, stylesheets, icons, video, audio, and iframes, all on by default.
- Checks what layouts and includes reference, such as navigation, and reports a broken one once, from the layout, rather than from every page.
- Follows `jekyll-redirect-from` redirects, and checks other sites with [ruby-link-checker](https://github.com/dblock/ruby-link-checker), concurrently, with retries.
- Remembers links that worked in a cache, so later builds only check what's new.
- Reports links blocked by bot protection, such as Cloudflare challenges, as unverified, rather than as dead.
- Lets you choose what's checked, find references in tags of your own, exclude sites, URLs, and paths, and list some kinds as warnings rather than fail the build.
- Writes a Markdown report that suggests exclusions for links whose results change from one run to the next.
- In pull requests, only checks the pages they change, and comments with the dead links; on your default branch, keeps an issue of dead links up to date.

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

Check links while building your site:

```sh
LINK_CHECKER=1 bundle exec jekyll build
```

The build fails when it finds dead links, and lists them with the pages that link to them. Fix them, see [Fixing Links](docs/fixing-links.md), and run it again until it passes.

## GitHub Actions

To check links on every push, every pull request, and twice a week, add this workflow:

```yaml
# .github/workflows/check-links.yml
name: Check Links

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '30 11 * * 0,3'

permissions:
  contents: read

jobs:
  check-links:
    uses: dblock/jekyll-ruby-link-checker/.github/workflows/check-links.yml@v0.1.0
```

A run fails when it finds dead links, and lists them in its summary. Fix them, push, and repeat until the run passes.

To also comment on pull requests with their dead links, and keep an issue of the dead links on your default branch up to date, add this workflow:

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

See [GitHub Actions](docs/github-actions.md) for the options of both workflows, and for the action on GitHub Marketplace, which you can add as a step to a job of your own.

## Documentation

- [Usage](docs/usage.md): what the plugin checks and reports.
- [Configuration](docs/configuration.md): every option of `link_checker` in `_config.yml`.
- [GitHub Actions](docs/github-actions.md): check links on every push and pull request, and report them in comments and an issue.
- [Fixing Links](docs/fixing-links.md): what to do about dead, unverified, and moved links.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [DESIGN.md](DESIGN.md), [RELEASING.md](RELEASING.md), and [CHANGELOG.md](CHANGELOG.md).

## License

MIT License, see [LICENSE.txt](LICENSE.txt).
