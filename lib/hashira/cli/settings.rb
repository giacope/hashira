# frozen_string_literal: true

class Hashira::CLI::Settings
  def initialize(argv)
    @argv = argv
  end

  def options
    typed = parse(@argv)
    Hashira::CLI::Usage::PAGES.include?(typed.mode) ? typed : layered(typed)
  end

  private

  def layered(typed)
    file = Hashira::CLI::ConfigFile.new(@argv)
    file.vet { parse(it) }
    base = typed.directories.empty? ? @argv + file.directories : @argv
    parse(file.flags.reduce(base) { |kept, flag| widened(kept, flag) })
  end

  def widened(kept, flag)
    tried = kept + flag
    fits?(tried) ? tried : kept
  end

  def fits?(argv)
    parse(argv)
    true
  rescue Hashira::Error
    false
  end

  def parse(argv) = Hashira::CLI::CommandLine.new(argv).options
end
