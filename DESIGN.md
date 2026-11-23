# Design

This plugin checks the links in a Jekyll site while it builds, and fails the build when a link is dead. It started as `_plugins/link-checker.rb` in [code.dblock.org](https://github.com/dblock/code.dblock.org) and the [OpenSearch documentation](https://github.com/opensearch-project/documentation-website).

## Scope

It checks the references in the rendered pages and documents of a site, and, unless `layouts` is off, in their layouts and includes. References to the site itself are checked against the built files, including anchors and `jekyll-redirect-from` redirects. References to other sites are checked with [ruby-link-checker](https://github.com/dblock/ruby-link-checker), and share its cache.

It doesn't work with other site generators, or fix links. [html-proofer](https://github.com/gjtorikian/html-proofer) also checks HTML for other problems, such as missing `alt` text.

## Kinds

`Check::KINDS` defines each built-in kind by its label in reports and its `tags`: selectors, and the attributes of matching elements that hold URLs. The configuration uses the same shape, so a site can replace the `tags` of a kind, and the built-in kinds are defaults rather than special cases. `Selector` supports a tag, words that attributes must contain (`[rel~=stylesheet]`), and `:not(...)` of those, which is enough to tell stylesheets from other `<link>` tags without hard-coded rules; anything else is rejected rather than half-supported. `References` reads each element's attributes by exact name, quoted or not, so `data-src` is never mistaken for `src`, and asks each kind for the URLs it holds. Browsers remove tabs and newlines from URLs, so the plugin does too, after splitting `srcset` into its candidates.

Every kind goes through the same resolution, exclusions, and cache, so `data:` images are skipped like links with other schemes, and each reference keeps its kind, so reports say `image not found` or `image: HTTP 404`. Each `Kind` carries its own options, so the checker never asks the configuration what to do with a reference. A URL keeps the kind it was first found as, so a URL both linked and shown as an image is checked once.

`fail: false` routes dead references to warnings, which are logged and listed in the report, but not counted on its first line, which workflows read as the number of dead links. The `exclude` lists of a kind and of `check.defaults` are added to the top-level ones in `Urls#excluded?`, because exclusions only ever narrow what's checked; a kind's other options replace the defaults instead. `Exclude` is shared by the top level and by kinds, and takes the name of its section for errors, such as `check.images.exclude.paths`.

Every reasonable kind is on by default, so a new site checks everything it references without configuration, and turns off what it doesn't want. A kind of the site's own is any key of `check` other than the built-in kinds and `defaults`, and must set `tags`, which is how a misspelled built-in kind is caught rather than silently ignored.

## Layouts

Layouts and includes repeat on every page, so the checker splits what a page references by where it comes from, in `Sources`. It scans the page's content, which it reports from the page, and the rest of its output, which it reports from the page's layout. The output usually contains the content as it is, so the rest is what comes before and after it; when a layout changes the content, for example with a filter, the rest is the whole output, less the references of the content, counted once each. A broken link in navigation is then reported once, from `_layouts/default.html`, rather than from hundreds of pages. The final HTML doesn't say which nested layout or include a reference came from, so the location is the page's own layout, which is where to start looking. `layouts` is a top-level option rather than a kind under `check`, because it says where references come from, and applies to every kind.

## Performance

Collecting references runs while every page renders, so it's what the plugin adds to every build; `rake benchmark` measures it. `References` only reads the tags that some kind's selectors name, which skips the attributes of most elements, `Sources` scans each part of a page once, and the ids that anchors link to are read once per page. Kinds are told apart by name, because hashing a `Data` with its selectors is slow when counting references.

## Checking

Checking is off unless `LINK_CHECKER` is set, so that ordinary builds and `jekyll serve` stay fast. Hooks in `hooks.rb` start a `Checker` before rendering, collect links from each page after it renders, and check them all once the site is written, when the files that internal links point to exist.

`Configuration` reads and validates `link_checker` in `_config.yml`, with the help of `Values`, and rejects unknown options with the list of valid ones. `Urls` resolves relative links and applies exclusions, `InternalLinks` checks the built files, and `Report` collects the results, writes the report, and raises `DeadLinksError` when there are dead links.

Options that are passed to ruby-link-checker, such as `host_concurrency`, are only passed when they're set, so they keep ruby-link-checker's defaults. Their names describe the site rather than copy ruby-link-checker's. YAML can't hold a Ruby regular expression, so a `host_headers` key or an `exclude.urls` entry between slashes is read as one; other strings are matched exactly. `exclude.paths` patterns are matched against each link after links to the site are turned into paths, so they also see the full URLs of external links. That's documented rather than restricted to site paths, which would break existing configurations.

## Results

The plugin records each link from ruby-link-checker's `complete` event, which fires once with the final result. The `result` event fires for every attempt, including each redirect, so recording it would report redirected links as dead.

The Markdown report, which workflows post in issues and comments, lists each link with the pages that link to it, by title and linked to the live page, rather than in a table, because long URLs and source paths made tables unreadable. Link text is shortened, past three pages the rest are collapsed, unverified links, which often outnumber dead ones and come from a few sites, are grouped by site in a collapsed block, and the first line holds the number of dead links for workflows to read. The build log keeps source paths.

The report also suggests `exclude` settings, ready to copy into `_config.yml`, for links whose result may change from one run to the next: unverified links, by site when a site has several, and links to sites that answered with a server error, timed out, or refused the connection. Pages that are gone aren't suggested, because they need to be fixed rather than skipped. The suggestions don't merge with existing settings, which is good enough for a starting point.

Many sites block automated requests even when the page exists. ruby-link-checker reports those links as blocked, by their status or by a detected challenge, and the plugin lists them as unverified, without failing the build. Links that moved permanently are only listed with `permanent_redirects`, because many sites redirect most old links, for example from `http` to `https`, and the list would crowd out the dead links.

## Cache

Links that worked are remembered in ruby-link-checker's cache file, for `cache.ttl`. Dead links are never remembered, so they're checked on every build. Unverified links are only remembered with `cache.blocked_ttl`, which is meant to be shorter.

With `cache.prune`, entries the build didn't use are removed, but only when the build checks every page. A build that only checks changed pages would otherwise remove the entries of every other page.

## Pull Requests

`LINK_CHECKER_CHANGED_FILES` lists the files a change touched, and the plugin then only checks the pages among them. The whole site is still built, so links to unchanged pages resolve. Changed images and other static files don't need a check, and any other changed file, such as a layout, can change every page, so the plugin checks every page.

The workflow lists changed files with `git diff HEAD^1 HEAD`. On a pull request, `actions/checkout` checks out a merge commit whose first parent is the base branch, so two commits of history are enough. Deleted and renamed files check every page, because other pages may link to them.

## Baseline

Sites with old dead links would otherwise fail every pull request, or stop failing pull requests at all. `LINK_CHECKER_DEAD_LINKS` writes the dead links of a build, by URL, with their reason and pages, to a JSON file, and `LINK_CHECKER_BASELINE` reads one back. The comparison lives in the plugin, in `Report::Comparison`, so the log, the report, and the build agree on what fails, and it works outside GitHub Actions.

A dead link already existed when its URL is in the baseline, whatever page links to it, so renaming a post doesn't make its old dead links new. A link of the baseline is fixed when it isn't dead in this build, and every page that linked to it was checked, so a check of only changed pages doesn't claim fixes it didn't see. With `LINK_CHECKER_FAIL=new`, new dead links that failed in a way that may be temporary, the same ones that Suggested Exclusions picks, are warnings rather than failures, because ruby-link-checker already retried them. Without a baseline, nothing can be told apart, so no dead link fails the build: an evicted cache shouldn't block a pull request. Without `LINK_CHECKER_FAIL=new`, a baseline only splits the report, and every dead link still fails the build. The report lists new dead links in full, and existing and fixed ones collapsed, because there are often many, and nothing to do about them in a pull request; its first line counts only the dead links that fail the build.

## Workflows

`check-links.yml` restores the newest cache, builds the site, and saves the cache, even when the build fails on dead links, because ruby-link-checker writes the cache as it goes. GitHub caches can't be overwritten, so each run saves a new key, and the next run restores the newest one by prefix. GitHub also matches caches by path, so a site at the repository root caches the plain `cache-file`, the same path a hand-written workflow would use.

Dead links fail the build unless `LINK_CHECKER_FAIL` is off. That's handled in the plugin, not with `continue-on-error` in the workflow, so a build that fails for another reason still fails. The report starts with an HTML comment that holds the number of dead links, so workflows don't have to parse it.

`check-links.yml` only needs to read the repository, so it can run on pull requests from forks, which get a read-only token. `publish-report.yml` does the writing: it runs from the default branch with `workflow_run`, downloads the report, and comments or updates the issue, without checking out or running the code it checked. It only trusts the pull request number in the report when that pull request is still at the checked commit, so a report can't be posted on another pull request.

Neither workflow declares permissions, because a reusable workflow can't have more than its caller grants. Inputs must match their declared type, so callers quote `'true'`, `'false'`, and numbers passed to text inputs.
