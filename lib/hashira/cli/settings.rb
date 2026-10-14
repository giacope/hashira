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
    named = typed.directories
    file = Hashira::CLI::ConfigFile.new(@argv, Hashira::CLI::Home.build(named))
    file.vet { parse(it) }
    base = named.empty? ? @argv + file.directories : @argv
    settled(parse(file.flags.reduce(base) { |kept, flag| widened(kept, flag) }), file)
  end

  def settled(options, file)
    recorded = options.baseline
    home = file.home
    options.with(home:, rules: file.rules, baseline: recorded.empty? ? home.join(Hashira::CLI::BASELINE) : recorded)
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
