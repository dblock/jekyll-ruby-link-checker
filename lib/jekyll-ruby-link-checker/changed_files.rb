# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Selects the pages to check from the files a change touched, relative to the site source, for example in a pull
    # request. Changed pages and documents are checked, and changed static files don't need checking. Any other
    # change, such as a layout, an include, data, or configuration, can change every page, so all pages are checked.
    class ChangedFiles
      attr_reader :paths, :others

      # The changed pages to check from the list in `file`, or nil to check all pages.
      def self.pages(site, file)
        return nil unless file

        changed = new(site, read(file))
        changed.pages.tap do |pages|
          next if pages

          Jekyll.logger.info('LinkChecker:', "Checking all pages, because #{changed.others.min} and " \
                                             "#{changed.others.size - 1} other changed files aren't pages.")
        end
      end

      def self.read(file)
        File.readlines(file, chomp: true).map { |line| line.strip.delete_prefix('./').delete_prefix('/') }
            .reject(&:empty?).to_set
      end

      def initialize(site, paths)
        @paths = paths.to_set
        @pages = (site.pages + site.documents).to_set(&:relative_path)
        static = site.static_files.to_set { |file| file.relative_path.delete_prefix('/') }
        @others = @paths - @pages - static
      end

      # The changed pages to check, or nil to check all pages.
      def pages
        @others.empty? ? @paths & @pages : nil
      end
    end
  end
end
