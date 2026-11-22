# Releasing

Releases run in GitHub Actions with [ruby-gem-release](https://github.com/dblock/ruby-gem-release), from the manually dispatched [Release](.github/workflows/release.yml) workflow. It runs the tests, publishes the gem to RubyGems with Trusted Publishing, pushes a release commit and tag, creates a GitHub Release with the changelog section as its notes, and pushes the next development version. No RubyGems API key is stored. The local Bundler `rake release` tasks are disabled.

Publishing, tags, Trusted Publishing setup, and changes to branch protection require explicit authorization from the maintainer; this document does not grant it.

## One-Time Setup

1. Create a `release` environment, under **Settings → Environments**, or with `gh api --method PUT repos/dblock/jekyll-ruby-link-checker/environments/release`. Do not add required reviewers unless you want to approve every release.
2. On RubyGems, open the [pending trusted publishers page](https://rubygems.org/profile/oidc/pending_trusted_publishers) and add a GitHub Actions publisher for the gem `jekyll-ruby-link-checker`, repository `dblock/jekyll-ruby-link-checker`, workflow `release.yml`, and environment `release`. Set the separate workflow repository fields to `dblock` and `ruby-gem-release`, so RubyGems trusts the reusable workflow.
3. The workflow pushes the release and next development commits directly to `master`. Remove the pull request requirement from the `master` ruleset, and keep its force-push and deletion protections with no bypass actors. This permits direct pushes by everyone with write access, not only the workflow; ordinary development still goes through pull requests.

## Making a Release

Make sure `CHANGELOG.md` has notes under `## <version> (Next)`, and that CI passes on `master`. Then check the prerequisites without changing anything:

```sh
gh workflow run release.yml --repo dblock/jekyll-ruby-link-checker -f dry-run=true
```

For the first release, the gem doesn't exist on RubyGems yet, so pass your numeric RubyGems account ID:

```sh
gh workflow run release.yml --repo dblock/jekyll-ruby-link-checker -f rubygems-owner=YOUR_ACCOUNT_ID
```

For later releases, run the workflow without inputs, or with `-f version=X.Y.Z` to release a different version than the checked-in one.

## Verifying a Release

After the workflow succeeds, check that:

- [rubygems.org/gems/jekyll-ruby-link-checker](https://rubygems.org/gems/jekyll-ruby-link-checker) lists the new version,
- the `vX.Y.Z` tag and its [GitHub Release](https://github.com/dblock/jekyll-ruby-link-checker/releases) exist,
- `master` has the release commit, with the dated changelog section, followed by the next development version and a new `(Next)` section.

RubyGems can take a few minutes to show a new version. If a release fails partway, follow ruby-gem-release's [recovery instructions](https://github.com/dblock/ruby-gem-release/blob/master/RELEASING.md): reruns complete only the missing steps, without publishing twice or moving tags.
