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
    outcome = Evaluation::Sandbox.copy(File.join(fixture, "project")) { run(it, expect) }
    Evaluation::Sniff.new(File.basename(fixture), expect, outcome.findings).checks
  end

  def run(root, expect)
    settings = @tool.configured(expect["config"], File.join(root, ".evaluation.yml"))
    @tool.call(root, expect.fetch("args", []) + settings + ["--json"])
  end
end
