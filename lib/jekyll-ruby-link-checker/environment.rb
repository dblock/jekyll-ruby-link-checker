# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    class Configuration
      # Settings from environment variables, which change how one build checks links, mostly in CI. Files are relative
      # to the site source.
      module Environment
        # LINK_CHECKER_REPORT names a file for a Markdown report, for example in a CI workflow.
        def report_file(source) = env_file('LINK_CHECKER_REPORT', source)

        # LINK_CHECKER_CHANGED_FILES names a file that lists changed files, one per line, relative to the site source,
        # to only check the pages that changed, for example in a pull request.
        def changed_files(source) = env_file('LINK_CHECKER_CHANGED_FILES', source)

        # LINK_CHECKER_FAIL=0 reports dead links without failing the build, and LINK_CHECKER_FAIL=new only fails on dead
        # links that aren't in the baseline, for example on pull requests.
        def fail_on
          value = ENV.fetch('LINK_CHECKER_FAIL', '').strip.downcase
          return :none if %w[0 false no off].include?(value)

          value == 'new' ? :new : :all
        end

        # LINK_CHECKER_BASELINE names a file of the dead links of an earlier build, such as of the default branch, and
        # LINK_CHECKER_DEAD_LINKS a file to write the dead links of this build to, both relative to the site source.
        def baseline_file(source) = env_file('LINK_CHECKER_BASELINE', source)

        def dead_links_file(source) = env_file('LINK_CHECKER_DEAD_LINKS', source)

        private

        def env_file(name, source)
          file = ENV.fetch(name, '').strip
          file.empty? ? nil : File.expand_path(file, source)
        end
      end
    end
  end
end
