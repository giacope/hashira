# frozen_string_literal: true

class Hashira::CLI::CommandLine
  DEFAULT_BASELINE = "hashira_baseline.json"

  FORMATS = %w[text json dot mermaid].freeze

  CI_FLAGS = { "--update-baseline" => :update, "--ratchet" => :ratchet }.freeze

  def initialize(argv)
    @arguments = Hashira::CLI::Arguments.new(argv)
  end

  def options = shortcuts || parsed

  private

  def shortcuts
    return usage(:help) if delete("--help") || delete("-h")
    usage(:version) if delete("--version")
  end

  def usage(mode)
    Hashira::CLI::Options.new(directories: [], mode:, baseline: nil, fail_on: [], skip: [], packaging: :auto)
  end

  def parsed
    values = flags
    values[:mode] = mode(values[:fail_on])
    Hashira::CLI::Options.new(directories: @arguments.rest, **values)
  end

  def flags
    {
      skip: Hashira::CLI::Skip.parse(take("--skip", "")),
      fail_on: Hashira::CLI::FailOn.parse(take("--fail-on", "")),
      baseline: take("--baseline", DEFAULT_BASELINE), packaging: grouping
    }
  end

  def grouping = Hashira::CLI::PackageBy.parse(take("--package-by", ""))

  def mode(fail_on)
    case (asked = requested(fail_on).uniq(&:last))
    in [] then :text
    in [[_flag, mode]] then mode
    else conflict(asked)
    end
  end

  def conflict(asked)
    raise(Hashira::Error, "conflicting options: #{asked.map(&:first).join(" and ")}")
  end

  def requested(fail_on)
    CI_FLAGS.filter_map { |flag, mode| [flag, mode] if delete(flag) } + gate(fail_on) + formats
  end

  def gate(fail_on) = fail_on.empty? ? [] : [["--fail-on", :fail_on]]

  def formats
    chosen = format
    modes = chosen.empty? ? [] : [["--format #{chosen}", chosen.to_sym]]
    delete("--json") ? modes + [["--json", :json]] : modes
  end

  def format
    wanted = take("--format", "")
    return wanted if wanted.empty? || FORMATS.include?(wanted)
    raise(Hashira::Error.unknown("--format", wanted, FORMATS))
  end

  def take(flag, default) = @arguments.take(flag, default)

  def delete(flag) = @arguments.delete(flag)
end
