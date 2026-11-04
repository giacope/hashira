# frozen_string_literal: true

class Hashira::CLI::Settings
  def initialize(argv)
    @argv = argv
  end

  def options = parse(@argv).configured(self)

  def layered(named)
    home = Hashira::CLI::Home.build(named)
    file = Hashira::CLI::ConfigFile.new(@argv, home)
    file.vet { parse(it) }
    parse(file.widened(@argv, named) { fits?(it) }).options(file.rules, home)
  end

  private

  def fits?(argv)
    parse(argv)
    true
  rescue Hashira::Error
    false
  end

  def parse(argv) = Hashira::CLI::CommandLine.new(argv).options
end
