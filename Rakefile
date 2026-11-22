# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'ruby-gem-release/workflow/ruby_gem'
require 'ruby-gem-release/changelog'

# Releases run through the Release workflow, see RELEASING.md.
RubyGemRelease::Workflow::RubyGem.new(
  version: RubyGemRelease::Version::RubyConstant.new(
    path: 'lib/jekyll-ruby-link-checker/version.rb', constant: 'VERSION'
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
