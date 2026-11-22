# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'jekyll-ruby-link-checker/version'

Gem::Specification.new do |s|
  s.name        = 'jekyll-ruby-link-checker'
  s.version     = Jekyll::RubyLinkChecker::VERSION
  s.authors     = ['Daniel Doubrovkine']
  s.email       = ['dblock@users.noreply.github.com']
  s.homepage    = 'https://github.com/dblock/jekyll-ruby-link-checker'
  s.summary     = 'Check links in a Jekyll site during the build.'
  s.description = 'A Jekyll plugin that checks internal, anchor, and external links during the build ' \
                  'with ruby-link-checker, caching successful checks across builds.'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 3.3'

  s.files         = %w[CHANGELOG.md LICENSE.txt README.md] + Dir['lib/**/*.rb']
  s.require_paths = ['lib']
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/dblock/jekyll-ruby-link-checker/issues',
    'changelog_uri' => 'https://github.com/dblock/jekyll-ruby-link-checker/blob/master/CHANGELOG.md',
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/dblock/jekyll-ruby-link-checker'
  }

  s.add_dependency 'jekyll', '>= 4.0', '< 5'
  s.add_dependency 'ruby-link-checker', '~> 0.5'
  s.add_dependency 'typhoeus', '~> 1.4'
end
