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
    links: true                    # <a>, <area>, and <link> tags
    images:
      internal: true               # check images on the site (default: true)
      external: false              # don't fetch images from other sites
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

An entry of `exclude.urls` between slashes is a regular expression, because YAML can't hold one; any other entry is an exact URL. Patterns in `exclude.paths` are matched against every link: links to your site as paths, such as `/tags/ruby/`, and links to other sites as full URLs, so `'^https://github\.com/issues'` also works there. A duration is a number of seconds, or a number followed by `s`, `m`, `h`, `d`, or `w`. Dead links are never remembered, so they're checked again on every build. Pruning only happens when every page is checked. The options from `blocked` down are passed to ruby-link-checker; see its [documentation](https://github.com/dblock/ruby-link-checker#options) for details. Misspelled options fail the build with the list of valid ones.

A few environment variables change how a build checks links, mostly for CI:

```sh
LINK_CHECKER_CACHE=path/to/cache.json # use this cache file instead of cache.file
LINK_CHECKER_REPORT=report.md         # also write a report in Markdown
LINK_CHECKER_FAIL=0                   # warn about dead links instead of failing the build
LINK_CHECKER_CHANGED_FILES=files.txt  # only check the pages listed in this file, one per line
```

With `LINK_CHECKER_CHANGED_FILES`, a change to a layout, an include, or anything else that isn't a page or an image checks every page.

## What Is Checked

Each kind under `check` is `true`, which checks it with its defaults, `false`, which doesn't check it, or a set of options:

- `internal` checks references to the site itself, and `external` references to other sites; both default to `true`, or to what `check.defaults` sets.
- `tags` says where the kind is found, as selectors and the attributes that hold URLs, and replaces the default.

These are the kinds and the default `tags` of each:

```yaml
link_checker:
  check:
    links:
      tags:
        a: [href]
        area: [href]
        'link:not([rel~=preconnect], [rel~=dns-prefetch])': [href]
    images:
      tags:
        img: [src, srcset]
        source: [srcset]
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
