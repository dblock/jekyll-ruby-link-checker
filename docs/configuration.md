# Configuration

Configure the plugin with `link_checker` in `_config.yml`. Every option is optional; the values below are examples, and the comments give the defaults.

```yaml
link_checker:
  cache:
    file: .cache/link-checker.json # where to remember links that worked; add it to .gitignore (default: none)
    ttl: 30d                       # how long to remember them (default: 30d)
    blocked_ttl: 1d                # how long to remember unverified links (default: check them every time)
    prune: true                    # forget links that are no longer on the site (default: false)
  check:                           # what to check; each kind is true, false, or options (default: everything)
    defaults:                      # options for every kind that doesn't set its own
      external: true               # check references to other sites (default: true)
      exclude:                     # added to the top-level exclude, for every kind
        domains: [cdn.example.org]
    links:                         # <a>, <area>, and <link> tags other than stylesheets
      anchors: true                # check #fragments (default: true)
    images:
      internal: true               # check images on the site (default: true)
      external: false              # don't fetch images from other sites
      fail: false                  # list missing images as warnings, without failing the build (default: true)
      exclude:                     # added to the top-level exclude, for images only
        paths: ['^/images/old/']
    scripts: true                  # <script src>
    stylesheets: true              # <link rel="stylesheet">
    media: true                    # <video>, <audio>, <source src>, <track>, and video posters
    iframes: true                  # <iframe src>
  layouts: true                    # also check what layouts and includes reference, such as navigation (default: true)
  exclude:
    domains: [twitter.com]         # sites never to check, including their subdomains
    urls:                          # exact URLs, or /regular expressions/
      - https://example.org/flaky
      - '/\Ahttps:\/\/github\.com\/(issues|pulls)(\?|\z)/'
    paths: ['^/tags/']             # regular expressions, matched against links as written in the page
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

Misspelled options fail the build with the list of valid ones.

An entry of `exclude.urls` between slashes is a regular expression, because YAML can't hold one; any other entry is an exact URL. Patterns in `exclude.paths` are matched against links to your site as paths, such as `/tags/ruby/`, and against links to other sites as full URLs, such as `'^https://github\.com/issues'`.

A duration is a number of seconds, or a number followed by `s`, `m`, `h`, `d`, or `w`. Dead links are never remembered, so they're checked again on every build. Pruning only happens when every page is checked.

The options from `blocked` down are passed to ruby-link-checker; see its [documentation](https://github.com/dblock/ruby-link-checker#options).

## What Is Checked

Each kind under `check` is `true`, which checks it with the defaults, `false`, which doesn't check it, or a set of options:

- `internal` checks references to the site itself, and `external` references to other sites.
- `fail: false` lists dead references of the kind as warnings, in the log and in a section of the report, without failing the build or counting them as dead links.
- `exclude` takes the same lists as the top-level `exclude`, and adds them to it for the kind.
- `tags` says where the kind is found, as selectors and the attributes that hold URLs, and replaces the default.
- `anchors: false`, for links only, checks the pages that links point to, but not their `#fragments`.

`internal`, `external`, `fail`, and `anchors` default to `true`. `check.defaults` changes `internal`, `external`, `fail`, and `exclude` for every kind; a kind's own options win, except `exclude`, which adds to the defaults.

These are the kinds and the default `tags` of each:

```yaml
link_checker:
  check:
    links:
      tags:
        a: [href]
        area: [href]
        'link:not([rel~=stylesheet], [rel~=preconnect], [rel~=dns-prefetch])': [href]
    images:
      tags:
        img: [src, srcset]
        source: [srcset]
    scripts:
      tags:
        script: [src]
    stylesheets:
      tags:
        'link[rel~=stylesheet]': [href]
    media:
      tags:
        video: [src, poster]
        audio: [src]
        source: [src]
        track: [src]
    iframes:
      tags:
        iframe: [src]
```

A selector is a tag, such as `img`, optionally followed by words its attributes must contain, such as `link[rel~=stylesheet]`, and by words that rule it out, such as `a:not([rel~=external])`. A `srcset`, or any attribute whose name ends with `srcset`, holds several URLs, each followed by an optional descriptor such as `2x`. For example, to also check lazy-loaded images, whose URL a script copies from `data-src`:

```yaml
link_checker:
  check:
    images:
      tags:
        img: [src, srcset, data-src, data-srcset]
        source: [srcset, data-srcset]
```

Any other key under `check` is a kind of your own, which needs `tags`, and is reported by its name, such as `backgrounds not found`. It takes the same options as the built-in kinds. For example, to check background images that a script reads from `data-background`:

```yaml
link_checker:
  check:
    backgrounds:
      tags:
        div: [data-background]
        section: [data-background]
      external: false
```

A misspelled kind, such as `image`, doesn't have `tags`, so it fails the build with the list of built-in kinds.

## Environment Variables

These change how a build checks links, mostly in CI:

```sh
LINK_CHECKER_CACHE=path/to/cache.json # use this cache file instead of cache.file
LINK_CHECKER_REPORT=report.md         # also write a report in Markdown
LINK_CHECKER_FAIL=0                   # warn about dead links instead of failing the build
LINK_CHECKER_FAIL=new                 # only fail on dead links that aren't in the baseline
LINK_CHECKER_BASELINE=base.json       # the dead links of an earlier build, such as of the default branch
LINK_CHECKER_DEAD_LINKS=dead.json     # write the dead links of this build, to use as a baseline later
LINK_CHECKER_CHANGED_FILES=files.txt  # only check the pages listed in this file, one per line
```

With `LINK_CHECKER_CHANGED_FILES`, a change to a layout, an include, or anything else that isn't a page or an image checks every page.

A baseline tells new dead links from existing ones: a dead link whose URL is in the baseline already existed, and a link of the baseline that the checked pages no longer link to as dead is fixed. With `LINK_CHECKER_FAIL=new`, only new dead links fail the build, and new ones that failed in a way that may be temporary, such as `HTTP 503` or a timeout, are warnings. Without a baseline, for example on the first run, no dead link fails the build, with a warning. A baseline that can't be read is ignored, with a warning.
