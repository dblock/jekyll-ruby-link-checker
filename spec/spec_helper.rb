# frozen_string_literal: true

require 'bundler/setup'
require_relative 'coverage_setup'

SimpleCov.start do
  enable_coverage :branch
  skip '/spec/'
end

require 'jekyll-ruby-link-checker'
require 'tmpdir'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |file| require file }

# Specs never use the network; a request without a stub fails.
Typhoeus::Config.block_connection = true

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
  config.include SiteHelper

  config.after do
    Typhoeus::Expectation.clear
  end
end
