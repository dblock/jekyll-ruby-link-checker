# frozen_string_literal: true

require 'yaml'

# GitHub versions caches by path, so restoring and saving must use the same path, and a site at the root must use
# the bare cache file, as hand-written workflows do, to keep their caches.
RSpec.describe 'check-links workflow cache path' do # rubocop:disable RSpec/DescribeClass
  let(:job) do
    YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__)).dig('jobs', 'check')
  end

  def step(name)
    job.fetch('steps').find { |s| s['name'] == name }
  end

  it 'uses the bare cache file for a site at the root, and the site directory otherwise' do
    expect(job.dig('env', 'CACHE_PATH').gsub(/\s+/, ' ').strip).to eq(
      "${{ (inputs.working-directory == '.' || inputs.working-directory == '') && inputs.cache-file " \
      "|| format('{0}/{1}', inputs.working-directory, inputs.cache-file) }}"
    )
  end

  it 'restores and saves the same path' do
    expect(step('Restore Link Checker Cache').dig('with', 'path')).to eq('${{ env.CACHE_PATH }}')
    expect(step('Save Link Checker Cache').dig('with', 'path')).to eq('${{ env.CACHE_PATH }}')
    expect(step('Save Link Checker Cache')['if']).to eq("always() && hashFiles(env.CACHE_PATH) != ''")
  end
end
