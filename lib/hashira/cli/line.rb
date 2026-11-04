# frozen_string_literal: true

class Hashira::CLI::Line
  def initialize(parsed, directories, mode)
    @parsed = parsed
    @directories = directories
    @mode = mode
  end

  def check = Hashira::CLI::Needs.new(@parsed, @mode).check

  def configured(settings) = settings.layered(@directories)

  def options(rules, home)
    Hashira::CLI::Options.new(
      Hashira::CLI::Output.new(@mode, given("--top"), given("--compact")),
      Hashira::CLI::Scope.new(@directories, given("--skip"), given("--only"), given("--package-by")),
      Hashira::CLI::Judgement.new(given("--kind"), given("--fail-on"), given("--strict"), rules),
      Hashira::CLI::Record.build(given("--baseline"), home)
    )
  end

  private

  def given(name) = @parsed.given(name)
end
