# frozen_string_literal: true

require 'open3'
require 'yaml'

# Runs the "List Changed Files" step of the check-links workflow in a repository whose HEAD is a pull request merge
# commit, as actions/checkout checks one out.
RSpec.describe 'check-links workflow changed files step' do # rubocop:disable RSpec/DescribeClass
  let(:dir) { Dir.mktmpdir }
  let(:repo) { File.join(dir, 'repo') }
  let(:site) { File.join(repo, 'site') }
  let(:github_env) { File.join(dir, 'github_env') }
  let(:step) do
    workflow = YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__))
    workflow.dig('jobs', 'check', 'steps').find { |s| s['name'] == 'List Changed Files' }
  end

  before do
    FileUtils.mkdir_p(File.join(site, 'posts'))
    git('init', '--quiet', '--initial-branch=main')
    write('README.md', 'Readme')
    write('site/index.md', 'Index')
    write('site/about.md', 'About')
    write('site/posts/hello world.md', 'Hello')
    commit('Base')
  end

  after { FileUtils.rm_rf(dir) }

  def git(*args)
    env = { 'GIT_AUTHOR_NAME' => 'A', 'GIT_AUTHOR_EMAIL' => 'a@example.com', 'GIT_COMMITTER_NAME' => 'A',
            'GIT_COMMITTER_EMAIL' => 'a@example.com', 'GIT_CONFIG_GLOBAL' => File::NULL }
    output, status = Open3.capture2e(env, 'git', '-C', repo, *args)
    raise output unless status.success?
  end

  def write(path, content)
    File.write(File.join(repo, path), content)
  end

  def commit(message)
    git('add', '--all')
    git('commit', '--quiet', '-m', message)
  end

  # Commits the change on a branch and merges it into main, like the merge commit of a pull request.
  def pull_request
    git('switch', '--quiet', '-c', 'topic')
    yield
    commit('Change')
    git('switch', '--quiet', 'main')
    write('site/index.md', 'Index, changed on main')
    commit('Main')
    git('merge', '--quiet', '--no-ff', '-m', 'Merge', 'topic')
  end

  # Runs the step in the site directory and returns its output and the changed files it passes on, or nil.
  def run_step
    env = { 'RUNNER_TEMP' => dir, 'GITHUB_ENV' => github_env, 'GIT_CONFIG_GLOBAL' => File::NULL }
    output, status = Open3.capture2e(env, 'bash', '-c', step.fetch('run'), chdir: site)
    expect(status).to be_success
    variable = File.exist?(github_env) ? File.read(github_env) : ''
    file = variable[/^LINK_CHECKER_CHANGED_FILES=(.*)$/, 1]
    [output, file && File.read(file)]
  end

  it 'lists the files the pull request changed in the site, relative to it' do
    pull_request do
      write('README.md', 'Changed readme')
      write('site/about.md', 'Changed about')
      write('site/posts/hello world.md', 'Changed hello')
      write('site/new.md', 'New')
    end

    expect(run_step.last).to eq("about.md\nnew.md\nposts/hello world.md\n")
  end

  it 'checks all pages when a file was deleted or renamed' do
    pull_request { FileUtils.rm(File.join(site, 'about.md')) }
    expect(run_step).to eq(["Files were deleted or renamed; checking all pages.\n", nil])

    git('reset', '--quiet', '--hard', 'HEAD~2')
    git('branch', '--quiet', '-D', 'topic')
    pull_request { FileUtils.mv(File.join(site, 'about.md'), File.join(site, 'team.md')) }
    expect(run_step.last).to be_nil
  end

  it 'checks all pages when HEAD is not a merge commit' do
    expect(run_step).to eq(["HEAD isn't a pull request merge commit; checking all pages.\n", nil])
  end

  it 'runs only on pull requests with changed-files-only, which is on by default' do
    workflow = YAML.safe_load_file(File.expand_path('../../.github/workflows/check-links.yml', __dir__))

    expect(step['if']).to eq("inputs.changed-files-only && github.event_name == 'pull_request'")
    expect(workflow.dig(true, 'workflow_call', 'inputs',
                        'changed-files-only')).to include('type' => 'boolean', 'default' => true)
  end
end
