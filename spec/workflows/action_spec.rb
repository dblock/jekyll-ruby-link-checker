# frozen_string_literal: true

require 'yaml'

# The action and the check job of the check-links workflow run the same steps, one as a step in the caller's job, the
# other as a reusable workflow. A reusable workflow can't use an action from its own commit, so they're kept in sync.
RSpec.describe 'action' do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path('../..', __dir__) }
  let(:action) { YAML.safe_load_file(File.join(root, 'action.yml')) }
  let(:workflow) { YAML.safe_load_file(File.join(root, '.github/workflows/check-links.yml')) }

  # Each step by its name or action, with the action it uses or the script it runs.
  def steps(list)
    list.map { |step| [step['name'] || step['uses'], step['uses'] || step['run']] }
  end

  it 'runs the same steps as the check-links workflow, after its checkout, and the action sets up the cache path' do
    workflow_steps = steps(workflow.dig('jobs', 'check', 'steps')).drop(1)
    action_steps = steps(action.dig('runs', 'steps'))

    expect(action_steps.first.first).to eq('Set Up')
    expect(action_steps.drop(1)).to eq(workflow_steps)
  end

  it 'computes the cache and dead links paths, and when to fail, like the check-links workflow, and exports them' do
    set_up = action.dig('runs', 'steps').first
    %w[CACHE_PATH DEAD_LINKS_PATH FAIL_ON].each do |name|
      expect(set_up.dig('env', name)).to eq(workflow.dig('jobs', 'check', 'env', name))
      expect(set_up['run']).to include(%(echo "#{name}=$#{name}"))
    end
  end

  it 'has the inputs of the check-links workflow, but the runner, and their defaults' do
    inputs = workflow.dig(true, 'workflow_call', 'inputs').except('runs-on')

    expect(action['inputs'].keys).to match_array(inputs.keys)
    inputs.each { |name, input| expect(action.dig('inputs', name, 'default')).to eq(input['default'].to_s) }
  end

  it 'has a name, a description, and branding for GitHub Marketplace' do
    expect(action).to include('name' => 'Jekyll Ruby Link Checker')
    expect(action['branding']).to eq('icon' => 'link', 'color' => 'red')
    expect(action['description']).not_to be_empty
  end
end
