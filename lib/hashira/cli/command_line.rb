# frozen_string_literal: true

module Hashira
  class CLI
    class CommandLine
      DEFAULT_BASELINE = "hashira_baseline.json"

      FORMATS = %w[text json dot mermaid].freeze

      CI_FLAGS = { "--update-baseline" => :update_baseline, "--ratchet" => :ratchet }.freeze

      def initialize(argv)
        @arguments = argv.dup
      end

      def options = usage_options || parsed_options

      private

      def usage_options
        return usage(:help) if delete("--help") || delete("-h")

        usage(:version) if delete("--version")
      end

      def usage(mode) = Options.new(directories: [], mode:, baseline: nil, fail_on: [])

      def parsed_options
        values = flag_values
        mode = parse_mode(values[:fail_on])
        reject_unknown_flags
        Options.new(directories: @arguments, mode:, **values)
      end

      def flag_values
        { fail_on: FailOn.parse(take_value("--fail-on")),
          baseline: take_value("--baseline") || DEFAULT_BASELINE }
      end

      def parse_mode(fail_on)
        requested = requested_modes(fail_on).uniq(&:last)
        raise Error, "conflicting options: #{requested.map(&:first).join(" and ")}" if requested.size > 1

        requested.dig(0, 1) || :text
      end

      def requested_modes(fail_on)
        ci = CI_FLAGS.filter_map { |flag, mode| [flag, mode] if delete(flag) }
        ci + fail_on_mode(fail_on) + format_modes
      end

      def fail_on_mode(fail_on) = fail_on.empty? ? [] : [["--fail-on", :fail_on]]

      def format_modes
        format = take_format
        modes = format ? [["--format #{format}", format.to_sym]] : []
        delete("--json") ? modes + [["--json", :json]] : modes
      end

      def take_format
        format = take_value("--format")
        return format unless format
        raise Error, "unknown --format #{format.inspect} (use: #{FORMATS.join(", ")})" unless FORMATS.include?(format)

        format
      end

      def take_value(flag)
        position = @arguments.index(flag)
        return nil unless position

        _flag, value = @arguments.slice!(position, 2)
        raise Error, "#{flag} needs a value" unless value

        value
      end

      def delete(flag) = @arguments.delete(flag)

      def reject_unknown_flags
        stray = @arguments.find { _1.start_with?("-") }
        raise Error, "unknown option #{stray}" if stray
      end
    end
  end
end
