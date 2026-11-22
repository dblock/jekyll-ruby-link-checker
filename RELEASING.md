# Releasing

Releases are not set up yet. They will use [ruby-gem-release](https://github.com/dblock/ruby-gem-release): a manually dispatched GitHub Actions workflow that runs the tests, publishes the gem to RubyGems with Trusted Publishing from a `release` environment, tags the release, creates a GitHub Release, and bumps the version for the next development iteration.

Publishing, tags, and Trusted Publishing setup require authorization from the maintainer. This document will describe the exact steps once the release workflow exists.
