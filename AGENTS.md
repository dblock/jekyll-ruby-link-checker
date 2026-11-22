# Working on `jekyll-ruby-link-checker`

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, commands, tests, and PR rules, and [DESIGN.md](DESIGN.md) for the design. This project is a Jekyll plugin that checks a site's links during the build, plus a reusable GitHub Actions workflow that keeps the link cache between runs. It is not a general-purpose link checker; external checks belong in [ruby-link-checker](https://github.com/dblock/ruby-link-checker).

## Rules to Keep

- The plugin lives in `lib/`, the reusable workflow in `.github/workflows/`, and specs in `spec/`.
- Support Ruby 3.3 and newer and Jekyll 4. Use only public Jekyll hooks and ruby-link-checker APIs.
- Keep checking off unless `LINK_CHECKER` is set, so ordinary builds and `jekyll serve` stay fast.
- Never cache failures or errors; dead links must be checked again on every run.
- Reject unknown configuration options with an error that lists the valid ones.
- Test against real fixture sites built with Jekyll. Do not make network requests in specs; stub Typhoeus.
- Keep the reusable workflow saving the cache when the build fails, and keep `spec/fixtures/site` checked by the Integration workflow.
- Keep `check-links.yml` read-only, so it can run on pull requests from forks; anything that writes, such as comments and issues, belongs in `publish-report.yml`, which must never check out or run the checked code and treats the report as data.
- Aim for full line and branch coverage with meaningful specs.
- Pin every external action and reusable workflow to a full commit SHA with a trailing version comment.
- Keep YAML workflow, job, and step names in Title Case.

## Safety

- Do not merge, publish, dispatch the Release workflow, or create release tags without authorization. Releases run only through the Release workflow, as described in [RELEASING.md](RELEASING.md); the local Bundler release tasks are disabled.
- Never force-push `master`.
- Preserve unrelated worktree changes, and never discard changes to clean up.
