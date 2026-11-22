# Design

This plugin checks the links in a Jekyll site while it builds, and fails the build when a link is dead. It started as `_plugins/link-checker.rb` in [code.dblock.org](https://github.com/dblock/code.dblock.org) and the [OpenSearch documentation](https://github.com/opensearch-project/documentation-website).

## Scope

It checks every `<a href>` in the rendered pages and documents of a site. Links to the site itself are checked against the built files, including anchors and `jekyll-redirect-from` redirects. Links to other sites are checked with [ruby-link-checker](https://github.com/dblock/ruby-link-checker).

It doesn't check images or scripts, work with other site generators, or fix links. [html-proofer](https://github.com/gjtorikian/html-proofer) checks built HTML more broadly.

## Checking

Checking is off unless `LINK_CHECKER` is set, so that ordinary builds and `jekyll serve` stay fast. Hooks in `hooks.rb` start a `Checker` before rendering, collect links from each page after it renders, and check them all once the site is written, when the files that internal links point to exist.

`Configuration` reads and validates `link_checker` in `_config.yml`, with the help of `Values`, and rejects unknown options with the list of valid ones. `Urls` resolves relative links and applies exclusions, `InternalLinks` checks the built files, and `Report` collects the results, writes the report, and raises `DeadLinksError` when there are dead links.

Options that are passed to ruby-link-checker, such as `host_concurrency`, are only passed when they're set, so they keep ruby-link-checker's defaults. Their names describe the site rather than copy ruby-link-checker's. YAML can't hold a Ruby regular expression, so a `host_headers` key or an `exclude.urls` entry between slashes is read as one; other strings are matched exactly. `exclude.paths` patterns are matched against each link after links to the site are turned into paths, so they also see the full URLs of external links. That's documented rather than restricted to site paths, which would break existing configurations.

## Results

The plugin records each link from ruby-link-checker's `complete` event, which fires once with the final result. The `result` event fires for every attempt, including each redirect, so recording it would report redirected links as dead.

Many sites block automated requests even when the page exists. ruby-link-checker reports those links as blocked, by their status or by a detected challenge, and the plugin lists them as unverified, without failing the build. Links that moved permanently are only listed with `permanent_redirects`, because many sites redirect most old links, for example from `http` to `https`, and the list would crowd out the dead links.

## Cache

Links that worked are remembered in ruby-link-checker's cache file, for `cache.ttl`. Dead links are never remembered, so they're checked on every build. Unverified links are only remembered with `cache.blocked_ttl`, which is meant to be shorter.

With `cache.prune`, entries the build didn't use are removed, but only when the build checks every page. A build that only checks changed pages would otherwise remove the entries of every other page.

## Pull Requests

`LINK_CHECKER_CHANGED_FILES` lists the files a change touched, and the plugin then only checks the pages among them. The whole site is still built, so links to unchanged pages resolve. Changed images and other static files don't need a check, and any other changed file, such as a layout, can change every page, so the plugin checks every page.

The workflow lists changed files with `git diff HEAD^1 HEAD`. On a pull request, `actions/checkout` checks out a merge commit whose first parent is the base branch, so two commits of history are enough. Deleted and renamed files check every page, because other pages may link to them.

## Workflows

`check-links.yml` restores the newest cache, builds the site, and saves the cache, even when the build fails on dead links, because ruby-link-checker writes the cache as it goes. GitHub caches can't be overwritten, so each run saves a new key, and the next run restores the newest one by prefix. GitHub also matches caches by path, so a site at the repository root caches the plain `cache-file`, the same path a hand-written workflow would use.

Dead links fail the build unless `LINK_CHECKER_FAIL` is off. That's handled in the plugin, not with `continue-on-error` in the workflow, so a build that fails for another reason still fails. The report starts with an HTML comment that holds the number of dead links, so workflows don't have to parse it.

`check-links.yml` only needs to read the repository, so it can run on pull requests from forks, which get a read-only token. `publish-report.yml` does the writing: it runs from the default branch with `workflow_run`, downloads the report, and comments or updates the issue, without checking out or running the code it checked. It only trusts the pull request number in the report when that pull request is still at the checked commit, so a report can't be posted on another pull request.

Neither workflow declares permissions, because a reusable workflow can't have more than its caller grants. Inputs must match their declared type, so callers quote `'true'`, `'false'`, and numbers passed to text inputs.
