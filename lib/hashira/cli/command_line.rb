# frozen_string_literal: true

class Hashira::CLI::CommandLine
  def initialize(argv)
    @argv = argv
  end

  def options = page || parsed

  private

  def arguments = @_arguments ||= Hashira::CLI::Arguments.new(@argv)

  def page
    flag = Hashira::CLI::FLAGS.select(&:page?).find { seen?(it) }
    Hashira::CLI::Options.build(flag.mode) if flag
  end

  def seen?(flag) = flag.names.any? { arguments.drop(it) }

  def parsed
    parses = Hashira::CLI::FLAGS.reject(&:page?).to_h { [it, it.read(arguments)] }
    fields = parses.to_h { |flag, value| [flag.field, value] }.except(nil)
    Hashira::CLI::Options.new(directories: arguments.rest, mode: mode(parses), **fields).tap { Hashira::CLI::Needs.new(it).check }
  end

  def mode(parses)
    case (asked = parses.filter_map { |flag, value| flag.bid(value) }.uniq(&:last))
    in [] then :text
    in [[_flag, mode]] then mode
    else raise(Hashira::Error, "conflicting options: #{asked.map(&:first).join(" and ")}")
    end
  end
end
