# frozen_string_literal: true

require 'open3'
require 'yaml'

# Runs the "Update Issue" step of the reusable workflow with a fake `gh` that records its arguments.
RSpec.describe 'check-links workflow issue step' do # rubocop:disable RSpec/DescribeClass
  let(:dir) { Dir.mktmpdir }
  let(:report) { File.join(dir, 'report.md') }
  let(:log) { File.join(dir, 'gh.log') }
  let(:run_url) { 'https://github.com/o/r/actions/runs/1' }
  let(:script) do
    workflow = YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__))
    workflow.dig('jobs', 'check', 'steps').find { |step| step['name'] == 'Update Issue' }.fetch('run')
  end

  before do
    FileUtils.mkdir_p(File.join(dir, 'bin'))
    File.write(File.join(dir, 'bin', 'gh'), <<~SH)
      #!/bin/bash
      printf '%s\\n' "$*" >> "$GH_LOG"
      if [ "$1 $2" = "issue list" ]; then echo "$OPEN_ISSUE"; fi
      if [ "$1 $2" = "issue view" ]; then echo "$ISSUE_STATE"; fi
    SH
    FileUtils.chmod(0o755, File.join(dir, 'bin', 'gh'))
  end

  after { FileUtils.rm_rf(dir) }

  def write_report(dead)
    File.write(report, "<!-- jekyll-ruby-link-checker dead links: #{dead} -->\n\nChecked links.\n")
  end

  # Returns the `gh` commands that change issues, one per line, with multi-line bodies joined.
  def run_step(issue:, open_issue: '', issue_state: '')
    env = {
      'PATH' => "#{File.join(dir, 'bin')}:#{ENV.fetch('PATH')}", 'GH_LOG' => log, 'OPEN_ISSUE' => open_issue,
      'ISSUE_STATE' => issue_state, 'REPORT' => report, 'ISSUE' => issue, 'RUN_URL' => run_url
    }
    _, status = Open3.capture2e(env, 'bash', '-c', script)
    expect(status).to be_success
    changes
  end

  def changes
    return [] unless File.exist?(log)

    File.read(log).split(/\n(?=issue )/).map(&:chomp).reject { |line| line.start_with?('issue list', 'issue view') }
  end

  def body(dead)
    "<!-- jekyll-ruby-link-checker dead links: #{dead} -->\n\nChecked links.\n\nFrom #{run_url}."
  end

  context 'with true' do
    it 'opens an issue titled Broken Links when links are dead' do
      write_report(2)

      expect(run_step(issue: 'true')).to eq(["issue create --title Broken Links --body #{body(2)}"])
    end

    it 'closes the open Broken Links issue when all links work' do
      write_report(0)

      expect(run_step(issue: 'TRUE',
                      open_issue: '42')).to eq(["issue close 42 --comment All links work, as of #{run_url}."])
    end
  end

  context 'with a title' do
    it 'opens an issue with that title when links are dead' do
      write_report(1)

      expect(run_step(issue: 'Dead Links')).to eq(["issue create --title Dead Links --body #{body(1)}"])
    end

    it 'updates the open issue with that title when links are still dead' do
      write_report(1)

      expect(run_step(issue: 'Dead Links', open_issue: '42')).to eq(["issue edit 42 --body #{body(1)}"])
    end

    it 'does nothing when all links work and no issue is open' do
      write_report(0)

      expect(run_step(issue: 'Dead Links')).to be_empty
    end
  end

  context 'with an issue number' do
    it 'updates and reopens the issue when links are dead' do
      write_report(3)

      expect(run_step(issue: '123',
                      issue_state: 'CLOSED')).to eq(["issue edit 123 --body #{body(3)}",
                                                     'issue reopen 123'])
    end

    it 'updates the open issue without reopening it, and accepts a leading #' do
      write_report(3)

      expect(run_step(issue: '#123', issue_state: 'OPEN')).to eq(["issue edit 123 --body #{body(3)}"])
    end

    it 'closes the issue when all links work' do
      write_report(0)

      expect(run_step(issue: '123',
                      issue_state: 'OPEN')).to eq(["issue close 123 --comment All links work, as of #{run_url}."])
    end

    it 'leaves a closed issue closed when all links work' do
      write_report(0)

      expect(run_step(issue: '123', issue_state: 'CLOSED')).to be_empty
    end
  end

  it 'leaves the issue unchanged when the build failed before checking links' do
    expect(run_step(issue: '123', issue_state: 'OPEN')).to be_empty
  end

  it 'runs only when issue is set to something other than false' do
    workflow = YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__))
    step = workflow.dig('jobs', 'check', 'steps').find { |s| s['name'] == 'Update Issue' }

    expect(step['if']).to eq("always() && inputs.issue != 'false' && inputs.issue != ''")
    expect(workflow.dig(true, 'workflow_call', 'inputs', 'issue')).to include('type' => 'string', 'default' => 'false')
  end
end
