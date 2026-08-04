# frozen_string_literal: true

class Hashira::CLI::CommandLine
  def initialize(argv)
    @arguments = Hashira::CLI::Arguments.new(argv)
  end

  def options = page || parsed

  private

  def page
    flag = Hashira::CLI::FLAGS.select(&:page?).find { seen?(it) }
    Hashira::CLI::Options.page(flag.mode) if flag
  end

  def seen?(flag) = flag.names.any? { @arguments.delete(it) }

  def parsed
    parses = Hashira::CLI::FLAGS.reject(&:page?).to_h { [it, it.read(@arguments)] }
    Hashira::CLI::Options.new(directories: @arguments.rest, mode: mode(parses), **fields(parses))
  end

  def fields(parses) = parses.to_h { |flag, value| [flag.field, value] }.except(nil)

  def mode(parses)
    case (asked = parses.filter_map { |flag, value| flag.bid(value) }.uniq(&:last))
    in [] then :text
    in [[_flag, mode]] then mode
    else conflict(asked)
    end
  end

  def conflict(asked)
    raise(Hashira::Error, "conflicting options: #{asked.map(&:first).join(" and ")}")
  end
end
