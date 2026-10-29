# frozen_string_literal: true

class Evaluation::Smells
  SUITE = "smells"

  def self.build(tool) = new(tool, Evaluation::Home.new.cases("smells"))

  def initialize(tool, root)
    @tool = tool
    @root = root
  end

  def checks = Evaluation::Sandbox.new(@root).expectations.flat_map { verdicts(it) }

  private

  def verdicts(fixture)
    expect = YAML.safe_load_file(File.join(fixture, "expect.yml"))
    outcome = Evaluation::Sandbox.new(File.join(fixture, "project")).copy { run(it, expect) }
    Evaluation::Sniff.new(File.basename(fixture), expect, outcome.findings).checks
  end

  def run(root, expect)
    Evaluation::History.new(root).replay(expect.fetch("history", []))
    settings = expect["config"]
    path = File.join(root, ".evaluation.yml")
    @tool.configure(settings, path)
    @tool.call(root, expect.fetch("args", []) + @tool.arguments(settings, path) + ["--json"])
  end
end
