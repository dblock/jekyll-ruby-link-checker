# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # The `check` section of `link_checker`: which kinds of references are checked, where each is found, with `tags`,
    # and how, with `internal` and `external`. `defaults` applies to every kind that doesn't set its own.
    class Check
      # Each built-in kind, with its label in reports and the attributes of the elements, by selector, that hold it.
      KINDS = {
        'links' => ['link', {
          'a' => %w[href], 'area' => %w[href], 'link:not([rel~=preconnect], [rel~=dns-prefetch])' => %w[href]
        }],
        'images' => ['image', { 'img' => %w[src srcset], 'source' => %w[srcset] }]
      }.freeze

      OPTIONS = %w[internal external].freeze
      KIND_OPTIONS = (%w[tags] + OPTIONS).freeze

      attr_reader :kinds

      def initialize(raw)
        raw ||= {}
        Values.invalid!('check', raw, 'a set of options') unless raw.is_a?(Hash)
        Values.known!(raw, ['defaults', *KINDS.keys], 'check')
        defaults = options(raw.fetch('defaults', {}), 'check.defaults', OPTIONS)
        @kinds = KINDS.filter_map { |name, (label, tags)| kind(name, label, tags, raw[name], defaults) }
      end

      private

      # A kind is checked unless it's `false`; `true`, or leaving it out, keeps its defaults.
      def kind(name, label, tags, value, defaults)
        return nil if value == false

        value = options(value.nil? || value == true ? {} : value, "check.#{name}", KIND_OPTIONS)
        Kind.new(name: name, label: label, tags: tags(value.fetch('tags', tags), "check.#{name}.tags"),
                 **OPTIONS.to_h { |option| [option.to_sym, value.fetch(option, defaults.fetch(option, true))] })
      end

      def options(value, name, valid)
        Values.invalid!(name, value, 'true, false, or a set of options') unless value.is_a?(Hash)
        Values.known!(value, valid, name)
        OPTIONS.each { |option| Values.boolean(value[option], "#{name}.#{option}") if value.key?(option) }
        value
      end

      # Selectors, such as `img` or `link[rel~=stylesheet]`, and the names of the attributes that hold URLs.
      def tags(value, name)
        Values.invalid!(name, value, 'a set of selectors and attributes') unless value.is_a?(Hash) && !value.empty?

        value.map { |selector, attributes| [Selector.parse(selector, name), names(attributes, "#{name}.#{selector}")] }
      end

      def names(value, name)
        names = Array(value)
        return names.map(&:downcase) if names.all? { |item| item.is_a?(String) && item.match?(/\A[a-z][\w:-]*\z/i) }

        Values.invalid!(name, value, 'a list of attribute names')
      end
    end
  end
end
