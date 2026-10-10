# frozen_string_literal: true

class Evaluation::Graphs
  SUITE = "coupling"

  QUIET = %w[--json --skip complexity,duplication,smells].freeze

  def self.build(tool) = new(tool, File.join(Evaluation::CASES, "coupling"))

  def initialize(tool, root)
    @tool = tool
    @root = root
  end

  def checks = Evaluation::Sandbox.expectations(@root).flat_map { verdicts(it) }

  private

  def verdicts(fixture)
    expect = YAML.safe_load_file(File.join(fixture, "expect.yml"))
    outcome = Evaluation::Sandbox.copy(File.join(fixture, "project")) { @tool.call(it, expect["args"] + QUIET) }
    Evaluation::Verdict.new(File.basename(fixture), expect, outcome).checks
  end
end
