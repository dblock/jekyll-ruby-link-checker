# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # A small CSS selector that says which elements hold a kind of reference: a tag, such as `img`, words its attributes
    # must contain, such as `link[rel~=stylesheet]`, and words that rule it out, such as `a:not([rel~=external])`.
    class Selector
      PATTERN = /\A([a-z][a-z0-9-]*)((?:\[[^\]]*\])*)(?::not\(([^)]*)\))?\z/i
      CONDITION = /\A\[\s*([a-z][\w:-]*)\s*~=\s*(["']?)([^"'\]\s]+)\2\s*\]\z/i

      attr_reader :text

      # Raises an error naming `name` when `text` isn't a selector.
      def self.parse(text, name)
        text = text.to_s.strip
        match = PATTERN.match(text)
        Values.invalid!(name, text, 'a selector, such as img or link[rel~=stylesheet]') unless match

        new(text, match[1].downcase, conditions(match[2].scan(/\[[^\]]*\]/), name, text),
            conditions(match[3].to_s.split(','), name, text))
      end

      def self.conditions(list, name, text)
        list.map(&:strip).reject(&:empty?).map do |condition|
          match = CONDITION.match(condition)
          Values.invalid!(name, text, 'a selector with conditions such as [rel~=stylesheet]') unless match

          [match[1].downcase, match[3].downcase]
        end
      end

      def initialize(text, tag, required, excluded)
        @text = text
        @tag = tag
        @required = required
        @excluded = excluded
      end

      # Whether an element with a lowercase `tag` and `attributes`, by lowercase name, matches.
      def match?(tag, attributes)
        tag == @tag && @required.all? { |condition| word?(attributes, *condition) } &&
          @excluded.none? { |condition| word?(attributes, *condition) }
      end

      private

      def word?(attributes, name, word)
        attributes[name].to_s.downcase.split.include?(word)
      end
    end
  end
end
