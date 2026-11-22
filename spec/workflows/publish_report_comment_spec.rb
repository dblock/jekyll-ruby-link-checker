# frozen_string_literal: true

require 'open3'
require 'yaml'

# Runs the "Comment on Pull Request" step of the publish workflow with a fake `gh` that records its arguments.
RSpec.describe 'publish-report workflow comment step' do # rubocop:disable RSpec/DescribeClass
  let(:dir) { Dir.mktmpdir }
  let(:report) { File.join(dir, 'link-checker-report.md') }
  let(:log) { File.join(dir, 'gh.log') }
  let(:run_url) { 'https://github.com/o/r/actions/runs/1' }
  let(:step) do
    workflow = YAML.safe_load_file(File.expand_path('../../.github/workflows/publish-report.yml', __dir__))
    workflow.dig('jobs', 'publish', 'steps').find { |s| s['name'] == 'Comment on Pull Request' }
  end

  before do
    FileUtils.mkdir_p(File.join(dir, 'bin'))
    File.write(File.join(dir, 'bin', 'gh'), <<~SH)
      #!/bin/bash
      printf '%s\\n' "$*" >> "$GH_LOG"
      case "$*" in
        "api repos/o/r/pulls/7 --jq .head.sha") echo "$PR_HEAD" ;;
        "api repos/o/r/issues/7/comments"*) echo "$COMMENT_ID" ;;
      esac
    SH
    FileUtils.chmod(0o755, File.join(dir, 'bin', 'gh'))
  end

  after { FileUtils.rm_rf(dir) }

  def write_report(dead, pull_request: '7')
    File.write(report, "<!-- jekyll-ruby-link-checker dead links: #{dead} -->\n\nChecked links.\n")
    File.write(File.join(dir, 'link-checker-pr.txt'), "#{pull_request}\n") if pull_request
  end

  # Returns the output and the `gh` commands that change comments.
  def run_step(pr_head: 'abc', comment_id: '')
    env = {
      'PATH' => "#{File.join(dir, 'bin')}:#{ENV.fetch('PATH')}", 'GH_LOG' => log, 'GH_REPO' => 'o/r',
      'PR_HEAD' => pr_head, 'COMMENT_ID' => comment_id, 'HEAD_SHA' => 'abc', 'REPORT' => report,
      'PR_FILE' => File.join(dir, 'link-checker-pr.txt'), 'MARKER' => marker, 'RUN_URL' => run_url
    }
    output, status = Open3.capture2e(env, 'bash', '-c', step.fetch('run'))
    expect(status).to be_success
    [output, changes]
  end

  def changes
    return [] unless File.exist?(log)

    File.read(log).split(/\n(?=api |pr )/).map(&:chomp).reject do |line|
      line.start_with?('api repos/o/r/pulls/7 ', 'api repos/o/r/issues/7/comments')
    end
  end

  def marker = '<!-- jekyll-ruby-link-checker report -->'

  def body(dead)
    "#{marker}\n<!-- jekyll-ruby-link-checker dead links: #{dead} -->\n\nChecked links.\n\nFrom #{run_url}."
  end

  it 'comments with the report when links are dead' do
    write_report(2)

    expect(run_step.last).to eq(["pr comment 7 --body #{body(2)}"])
  end

  it 'updates its earlier comment, including when the links are fixed' do
    write_report(0)

    expect(run_step(comment_id: '99').last)
      .to eq(["api --method PATCH repos/o/r/issues/comments/99 -f body=#{body(0)}"])
  end

  it 'does not comment when there are no dead links and no earlier comment' do
    write_report(0)

    expect(run_step.last).to be_empty
  end

  it 'does not comment when the pull request moved past the checked commit' do
    write_report(2)

    output, changes = run_step(pr_head: 'def')
    expect(output).to include('::warning::Pull request #7 is at def, not the checked abc; not commenting.')
    expect(changes).to be_empty
  end

  it 'does nothing without a report or a pull request number' do
    expect(run_step.last).to be_empty

    write_report(2, pull_request: nil)
    expect(run_step.last).to be_empty
  end

  it 'runs on pull requests unless comment is false, and searches comments by marker' do
    expect(step['if']).to include('inputs.comment', 'pull_request')
    expect(step.dig('env', 'MARKER')).to eq(marker)
  end
end
