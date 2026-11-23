# frozen_string_literal: true

# Times the plugin on a generated site, or on an existing one, without checking other sites. Run it with
# `bundle exec rake benchmark`; see CONTRIBUTING.md for its options.
require 'fileutils'
require 'tmpdir'
require 'jekyll'
require_relative '../lib/jekyll-ruby-link-checker'

module LinkCheckerBenchmark
  # Generates a site whose pages share a layout with navigation, a stylesheet, and a script, and whose content has
  # links to other pages, anchors, images with srcset, and links to other sites.
  class Site
    def initialize(source, pages:)
      @source = source
      @pages = pages
    end

    def write
      write_file('_layouts/default.html', layout)
      write_file('css/site.css', 'body { margin: 0; }')
      write_file('js/site.js', '')
      write_file('images/photo.png', '')
      write_file('images/photo-2x.png', '')
      @pages.times { |index| write_file("_posts/2020-01-01-post-#{index}.md", post(index)) }
    end

    private

    def write_file(path, content)
      file = File.join(@source, path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, content)
    end

    def layout
      navigation = Array.new(30) { |index| %(<a href="/2020/01/01/post-#{index % @pages}.html">Post #{index}</a>) }
      <<~HTML
        <!DOCTYPE html>
        <html><head><title>{{ page.title }}</title>
        <link rel="stylesheet" href="/css/site.css"><link rel="icon" href="/images/photo.png">
        <script src="/js/site.js"></script></head>
        <body><nav id="top">#{navigation.join(' ')}</nav><main>{{ content }}</main>
        <footer><a href="#top">Top</a> <a href="https://github.com/example/site/edit/{{ page.path }}">Edit</a></footer>
        </body></html>
      HTML
    end

    def post(index)
      links = Array.new(20) { |offset| "[Post](/2020/01/01/post-#{(index + offset + 1) % @pages}.html)" }
      sections = Array.new(5) { |section| "## Section #{section}\n\n[Back](#section-#{section})\n" }
      images = Array.new(5) do
        '<img src="/images/photo.png" srcset="/images/photo.png 1x, /images/photo-2x.png 2x" alt="Photo">'
      end
      external = Array.new(5) { |offset| "[Example](https://example.org/#{index}/#{offset})" }
      "---\nlayout: default\ntitle: Post #{index}\n---\n#{links.join(' ')}\n\n#{sections.join("\n")}\n" \
        "#{images.join("\n")}\n\n#{external.join(' ')}\n"
    end
  end

  # Adds up the time spent collecting references while pages are rendered, and checking them once the site is written.
  module Timing
    class << self
      attr_accessor :collect, :verify, :summary
    end

    def collect(page)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      super
    ensure
      Timing.collect += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    def verify
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      super
    ensure
      Timing.verify += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      Timing.summary = report.summary
    end
  end

  # Builds the site without and with the plugin, and prints the times.
  class Runner
    # Other sites are never checked, so the benchmark only measures the plugin.
    OFFLINE = { 'link_checker' => { 'check' => { 'defaults' => { 'external' => false } } } }.freeze

    def initialize(source:, runs:)
      @source = source
      @runs = runs
    end

    def run
      Jekyll::RubyLinkChecker::Checker.prepend(Timing)
      Jekyll.logger.log_level = :error
      time(nil)
      results = Array.new(@runs) { measure }
      print(results.min_by { |result| result[:with] })
    end

    private

    def measure
      Timing.collect = Timing.verify = 0
      without = time(nil)
      collect_before = Timing.collect
      with = time('1')
      { without: without, with: with, collect: Timing.collect - collect_before, verify: Timing.verify }
    end

    def time(env)
      Dir.mktmpdir do |destination|
        site = Jekyll::Site.new(config(destination))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        with_link_checker(env) { site.process }
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      end
    end

    # The site's own configuration, without the disk cache, so every build renders every page.
    def config(destination)
      options = { 'source' => @source, 'destination' => destination, 'quiet' => true, 'disable_disk_cache' => true }
      Jekyll.configuration(Jekyll::Utils.deep_merge_hashes(options, OFFLINE))
    end

    def with_link_checker(value)
      previous = ENV.fetch('LINK_CHECKER', nil)
      value ? ENV['LINK_CHECKER'] = value : ENV.delete('LINK_CHECKER')
      ENV['LINK_CHECKER_FAIL'] = '0'
      yield
    ensure
      previous ? ENV['LINK_CHECKER'] = previous : ENV.delete('LINK_CHECKER')
      ENV.delete('LINK_CHECKER_FAIL')
    end

    def print(result)
      puts format('Build without the plugin: %<s>.2fs', s: result[:without])
      puts format('Build with the plugin:    %<s>.2fs', s: result[:with])
      puts format('  Collecting references:  %<s>.2fs', s: result[:collect])
      puts format('  Checking them:          %<s>.2fs', s: result[:verify])
      puts Timing.summary
    end
  end
end

if $PROGRAM_NAME == __FILE__
  runs = Integer(ENV.fetch('RUNS', '3'))
  if ENV['SITE']
    LinkCheckerBenchmark::Runner.new(source: File.expand_path(ENV.fetch('SITE')), runs: runs).run
  else
    Dir.mktmpdir do |source|
      pages = Integer(ENV.fetch('PAGES', '1000'))
      LinkCheckerBenchmark::Site.new(source, pages: pages).write
      puts "Generated a site with #{pages} pages."
      LinkCheckerBenchmark::Runner.new(source: source, runs: runs).run
    end
  end
end
