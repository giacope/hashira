# frozen_string_literal: true

class Hashira::CLI::Settings
  BASELINE = "hashira_baseline.json"

  def initialize(argv, usage = Hashira::CLI::Usage.new)
    @argv = argv
    @usage = usage
  end

  def options
    typed = parse(@argv)
    @usage.page?(typed.mode) ? typed : layered(typed)
  end

  private

  def layered(typed)
    named = typed.directories
    home = Hashira::CLI::Home.build(named)
    file = Hashira::CLI::ConfigFile.new(@argv, home)
    file.vet { parse(it) }
    base = named.empty? ? @argv + file.directories : @argv
    settled(parse(file.flags.reduce(base) { |kept, flag| widened(kept, flag) }), file, home)
  end

  def settled(options, file, home)
    recorded = options.baseline
    options.with(home:, rules: file.rules, baseline: recorded.empty? ? home.join(BASELINE) : recorded)
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
