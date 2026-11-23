# frozen_string_literal: true

require 'yaml'

# Runs other than pull requests save their dead links in a cache of their own, and runs that only fail on new dead
# links restore it, as their baseline. Pull requests fail on new dead links by default.
RSpec.describe 'check-links workflow baseline' do # rubocop:disable RSpec/DescribeClass
  let(:job) do
    YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__)).dig('jobs', 'check')
  end

  def step(name)
    job.fetch('steps').find { |s| s['name'] == name }
  end

  def squish(text)
    text.gsub(/\s+/, ' ').strip
  end

  it 'fails on new dead links on pull requests and on all of them otherwise, unless fail-on-dead-links is set' do
    expect(squish(job.dig('env', 'FAIL_ON'))).to eq(
      "${{ inputs.fail-on-dead-links != '' && inputs.fail-on-dead-links " \
      "|| (github.event_name == 'pull_request' && 'new' || 'true') }}"
    )
  end

  it 'restores the dead links only when failing on new ones, and saves them only outside pull requests' do
    restore = step('Restore Dead Links')
    save = step('Save Dead Links')

    expect(restore['if']).to eq("env.FAIL_ON == 'new'")
    expect(save['if']).to eq("always() && github.event_name != 'pull_request' && hashFiles(env.DEAD_LINKS_PATH) != ''")
    expect([restore, save].map { |s| s.dig('with', 'path') }).to all(eq('${{ env.DEAD_LINKS_PATH }}'))
    expect(save.dig('with', 'key')).to eq(restore.dig('with', 'key'))
    expect(restore.dig('with', 'restore-keys')).to eq('${{ inputs.cache-key-prefix }}dead-links-')
  end

  it 'compares with the dead links when failing on new ones, and writes them outside pull requests' do
    env = step('Build and Check Links')['env']

    expect(env['LINK_CHECKER_FAIL']).to eq('${{ env.FAIL_ON }}')
    expect(squish(env['LINK_CHECKER_BASELINE'])).to start_with("${{ env.FAIL_ON == 'new' && ")
    expect(squish(env['LINK_CHECKER_DEAD_LINKS'])).to start_with("${{ github.event_name != 'pull_request' && ")
  end

  it 'restores the baseline before building, and saves it after' do
    names = job.fetch('steps').map { |s| s['name'] }

    expect(names.index('Restore Dead Links')).to be < names.index('Build and Check Links')
    expect(names.last).to eq('Save Dead Links')
  end
end
