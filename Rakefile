# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'ruby-gem-release/workflow/ruby_gem'
require 'ruby-gem-release/changelog'
require 'ruby-gem-release/version/references'

# Examples in the docs pin a release with a version tag at the end of the action or workflow path.
WORKFLOW_PIN = %r{
  dblock/jekyll-ruby-link-checker(?:/\.github/workflows/[\w-]+\.yml)?@v(?<version>\d+\.\d+\.\d+)(?![\w.+-])
}x

# Releases run through the Release workflow, see RELEASING.md.
# After a release, the next development version also points those examples at the release.
RubyGemRelease::Workflow::RubyGem.new(
  version: RubyGemRelease::Version::References.new(
    version: RubyGemRelease::Version::RubyConstant.new(
      path: 'lib/jekyll-ruby-link-checker/version.rb', constant: 'VERSION'
    ),
    references: { 'README.md' => [WORKFLOW_PIN], 'docs/**/*.md' => [WORKFLOW_PIN] }
  ),
  changelog: RubyGemRelease::Changelog::Intridea.new
).install_tasks

# Disable the local Bundler release tasks, so the workflow is the only way to release.
%w[release release:rubygem_push release:source_control_push].each do |name|
  Rake::Task[name].clear
  desc 'Disabled; releases run through GitHub Actions'
  task(name) { abort "#{name} is disabled; releases run through GitHub Actions" }
end

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Time the plugin on a generated site, or on SITE, without checking other sites'
task :benchmark do
  ruby 'benchmark/benchmark.rb'
end
