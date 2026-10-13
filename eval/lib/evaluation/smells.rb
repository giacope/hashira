# frozen_string_literal: true

class Evaluation::Smells
  SUITE = "smells"

  def self.build(tool) = new(tool, File.join(Evaluation::CASES, "smells"))

  def initialize(tool, root)
    @tool = tool
    @root = root
  end

  def checks = Evaluation::Sandbox.expectations(@root).flat_map { verdicts(it) }

  private

  def verdicts(fixture)
    expect = YAML.safe_load_file(File.join(fixture, "expect.yml"))
    outcome = Evaluation::Sandbox.copy(File.join(fixture, "project")) { @tool.call(it, expect.fetch("args", []) + @tool.every + ["--json"]) }
    Evaluation::Sniff.new(File.basename(fixture), expect, outcome.findings).checks
  end
end
