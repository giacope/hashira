# frozen_string_literal: true

class Hashira::CLI::CommandLine
  def initialize(argv, flags = Hashira::CLI::Flags.new, arguments = Hashira::CLI::Arguments.new(argv))
    @flags = flags
    @arguments = arguments
  end

  def options = @flags.page(@arguments).first || parsed

  private

  def parsed
    values = @flags.parse(@arguments)
    directories = @arguments.rest
    Hashira::CLI::Line.new(values, directories, values.mode).tap(&:check)
  end
end
