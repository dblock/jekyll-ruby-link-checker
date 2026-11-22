# frozen_string_literal: true

require 'open3'
require 'yaml'

# Runs the "Update Issue" step of the reusable workflow with a fake `gh` that records its arguments.
RSpec.describe 'check-links workflow issue step' do # rubocop:disable RSpec/DescribeClass
  let(:dir) { Dir.mktmpdir }
  let(:report) { File.join(dir, 'report.md') }
  let(:log) { File.join(dir, 'gh.log') }
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
    SH
    FileUtils.chmod(0o755, File.join(dir, 'bin', 'gh'))
  end

  after { FileUtils.rm_rf(dir) }

  def write_report(dead)
    File.write(report, "<!-- jekyll-ruby-link-checker dead links: #{dead} -->\n\nChecked links.\n")
  end

  def run_step(open_issue: '')
    env = {
      'PATH' => "#{File.join(dir, 'bin')}:#{ENV.fetch('PATH')}", 'GH_LOG' => log, 'OPEN_ISSUE' => open_issue,
      'REPORT' => report, 'TITLE' => 'Broken Links', 'RUN_URL' => 'https://github.com/o/r/actions/runs/1'
    }
    _, status = Open3.capture2e(env, 'bash', '-c', script)
    expect(status).to be_success
    File.exist?(log) ? File.readlines(log, chomp: true).reject { |line| line.start_with?('issue list') } : []
  end

  it 'opens an issue with the report when links are dead' do
    write_report(2)

    expect(run_step.join("\n")).to eq(
      "issue create --title Broken Links --body <!-- jekyll-ruby-link-checker dead links: 2 -->\n\n" \
      "Checked links.\n\nFrom https://github.com/o/r/actions/runs/1."
    )
  end

  it 'updates the open issue when links are still dead' do
    write_report(1)

    expect(run_step(open_issue: '42').first)
      .to eq('issue edit 42 --body <!-- jekyll-ruby-link-checker dead links: 1 -->')
  end

  it 'closes the open issue when all links work' do
    write_report(0)

    expect(run_step(open_issue: '42'))
      .to eq(['issue close 42 --comment All links work, as of https://github.com/o/r/actions/runs/1.'])
  end

  it 'does nothing when all links work and no issue is open' do
    write_report(0)

    expect(run_step).to be_empty
  end

  it 'leaves the issue unchanged when the build failed before checking links' do
    expect(run_step(open_issue: '42')).to be_empty
  end
end
