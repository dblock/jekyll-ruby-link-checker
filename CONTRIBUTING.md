# Contributing

Make one focused change per pull request.

## Setup and Validation

Ruby 3.3 or newer is supported.

```sh
bundle install
bundle exec rake
bundle exec rake build
```

`bundle exec rake` runs the specs and RuboCop; run it before every push. `bundle exec rake build` builds the gem when packaging changes. Coverage reports (HTML and LCOV) go to `coverage/`, and CI uploads them to Coveralls; aim to cover all runtime code with meaningful specs, including errors and edge cases.

RuboCop also checks the documentation and YAML files: prose and title-case headings with `rubocop-prose`, Ruby examples in Markdown with `rubocop-md`, spelling in comments and documentation with `rubocop-spellcheck`, and YAML with `rubocop-yaml`. Keep each paragraph on one source line. Fix spelling mistakes; add only reviewed project words to `.spellcheck.txt`. Keep YAML workflow, job, and step names in Title Case.

Danger checks the changelog in PR CI through the reusable [danger-pr-comment](https://github.com/danger/danger-pr-comment) workflows; you do not run it locally.

## Tests

Specs live in `spec/`. They build small sites with Jekyll in temporary directories, using `spec/support/site_helper.rb`, and stub external requests with Typhoeus; `Typhoeus::Config.block_connection` fails any request without a stub, so specs never use the network.

`spec/fixtures/site` is a small Jekyll site that uses the gem from this checkout. The Integration workflow checks its links with the reusable workflow on every PR, using real external requests and the GitHub Actions cache. To check it locally:

```sh
cd spec/fixtures/site
bundle install
LINK_CHECKER=1 LINK_CHECKER_CACHE=$PWD/.cache/link-checker.json bundle exec jekyll build
```

Validate workflow changes with:

```sh
actionlint -ignore 'bool value cannot be assigned' .github/workflows/*.yml
```

`actionlint` treats a quoted `'false'` passed to a string input of a reusable workflow, such as `report-artifact: 'false'`, as a boolean; GitHub Actions accepts it as a string, so that message is ignored.

## Pull Requests

- Work on a `dblock/<topic>` branch from `master` in the existing checkout. Use a separate worktree, as a sibling directory, only for work that runs in parallel.
- Split multiple changes into small stacked PRs: the bottom PR targets `master`, and each higher PR targets the branch below it.
- Keep each PR to one coherent commit. Amend and update it with `git push --force-with-lease`, never plain `--force`, and never force-push `master`.
- PRs are merged with rebase merges only.
- Update the documentation the change affects, and add a line to [CHANGELOG.md](CHANGELOG.md) for features, improvements, and fixes, in the form `- [#123](https://github.com/dblock/jekyll-ruby-link-checker/pull/123): Description - [@author](https://github.com/author).`
- After a PR merges, confirm it merged, remove its clean worktree if any, and delete the local branch.

See [RELEASING.md](RELEASING.md) for releases. The Release workflow pushes release and next development commits directly to `master`; ordinary changes still go through pull requests.
