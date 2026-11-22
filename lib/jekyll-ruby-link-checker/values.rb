# frozen_string_literal: true

module Jekyll
  module RubyLinkChecker
    # Reads and validates values of `link_checker` options, naming the option in errors.
    module Values
      DURATION_UNITS = { 's' => 1, 'm' => 60, 'h' => 3600, 'd' => 86_400, 'w' => 604_800 }.freeze

      module_function

      def duration(value, name)
        return value if value.is_a?(Integer) && value.positive?

        match = /\A(\d+)\s*([smhdw]?)\z/.match(value.to_s.strip)
        invalid!(name, value, 'a positive number of seconds or a duration such as 12h or 30d') unless match

        seconds = Integer(match[1], 10) * DURATION_UNITS.fetch(match[2], 1)
        invalid!(name, value, 'a positive duration') unless seconds.positive?
        seconds
      end

      # A number of seconds, which can be a fraction, or a duration such as 2s.
      def seconds(value, name)
        return value if value.is_a?(Numeric) && value.positive?

        duration(value, name)
      end

      def list(value, name)
        invalid!(name, value, 'a list') unless value.is_a?(Array)

        value.map(&:to_s)
      end

      def pattern(value, name)
        Regexp.new(value)
      rescue RegexpError => e
        invalid!(name, value, "a regular expression (#{e.message})")
      end

      def boolean(value, name)
        invalid!(name, value, 'true or false') unless [true, false].include?(value)
        value
      end

      def positive_integer(value, name)
        invalid!(name, value, 'a positive integer') unless value.is_a?(Integer) && value.positive?
        value
      end

      def non_negative_integer(value, name)
        invalid!(name, value, 'zero or a positive integer') unless value.is_a?(Integer) && !value.negative?
        value
      end

      # `false` or an empty list reports no status as blocked.
      def status_codes(value, name)
        return [] if value == false
        return value if value.is_a?(Array) && value.all? { |code| code.is_a?(Integer) && code.between?(100, 999) }

        invalid!(name, value, 'false or a list of HTTP status codes')
      end

      def headers(value, name)
        return value if value.is_a?(Hash) && value.all? { |key, header| key.is_a?(String) && header.is_a?(String) }

        invalid!(name, value, 'a set of header names and values')
      end

      # Hosts are exact names, or regular expressions between slashes, such as /(\A|\.)medium\.com\z/.
      def host_headers(value, name)
        invalid!(name, value, 'a set of hosts and their headers') unless value.is_a?(Hash)

        value.to_h do |host, headers|
          host = host.to_s
          key = host.length > 2 && host.start_with?('/') && host.end_with?('/') ? pattern(host[1..-2], name) : host
          [key, headers(headers, "#{name}.#{host}")]
        end
      end

      def invalid!(name, value, expected)
        raise Jekyll::Errors::InvalidConfigurationError, "#{option(name)} must be #{expected}, got #{value.inspect}"
      end

      def known!(options, valid, name)
        unknown = options.keys.map(&:to_s) - valid.map(&:to_s)
        return if unknown.empty?

        raise Jekyll::Errors::InvalidConfigurationError,
              "Unknown #{option(name)} option: #{unknown.join(', ')}. Valid options: #{valid.join(', ')}"
      end

      def option(name)
        name.empty? ? 'link_checker' : "link_checker.#{name}"
      end
    end
  end
end
