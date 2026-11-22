# frozen_string_literal: true

require 'bundler/setup'
require_relative 'coverage_setup'

SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
end

require 'jekyll-ruby-link-checker'

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
