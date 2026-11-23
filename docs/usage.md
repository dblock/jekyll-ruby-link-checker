# Usage

Checking is off by default, so that `jekyll serve` stays fast. Turn it on with `LINK_CHECKER`:

```sh
LINK_CHECKER=1 bundle exec jekyll build
```

The plugin checks every link in your pages and posts: links to other pages of the site, anchors such as `#usage`, relative links, and links to other sites. It also checks images, including `srcset` and `<picture>`, scripts, stylesheets, icons, video, audio, and iframes.

It checks what layouts and includes reference too, such as navigation, the stylesheets in `<head>`, and footers. A broken one is reported once, from the page's layout, such as `_layouts/default.html`, rather than from every page that uses it.

It prints a summary, and fails the build if it finds dead links, saying where each one is linked from:

```text
LinkChecker: Checked 412 internal and 2793 external links (2731 cached), skipped 25. Couldn't verify 1 link.
LinkChecker: Couldn't verify 1 link, which bot protection blocked:
https://www.linkedin.com/in/someone (HTTP 999), linked from about.md
LinkChecker: Found 3 dead links:
/images/missing.png (image not found), linked from _posts/2026-11-22-hello.md
/missing/ (page not found), linked from _layouts/default.html
https://example.org/gone (HTTP 404), linked from about.md
```

Anything other than a link says what it is, such as `image not found`, or `script: HTTP 404` for a script on another site.

Many sites block automated requests, for example with a 403 or a Cloudflare challenge, even when the page exists. Those links are reported as unverified, and don't fail the build.

To skip a page, add `link_checker: false` to its front matter. See [configuration](configuration.md#what-is-checked) to choose what's checked, and [fixing links](fixing-links.md) for what to do about dead and unverified links.
