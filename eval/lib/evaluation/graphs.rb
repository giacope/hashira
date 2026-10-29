# frozen_string_literal: true

class Evaluation::Graphs
  SUITE = "coupling"

  QUIET = %w[--json --skip complexity,duplication,smells].freeze

  def self.build(tool) = new(tool, Evaluation::Home.new.cases("coupling"))

  def initialize(tool, root)
    @tool = tool
    @root = root
  end

  def checks = Evaluation::Sandbox.new(@root).fixtures.flat_map { verdicts(it) }

  private

  def verdicts(fixture)
    expect = fixture.expect
    outcome = fixture.copy { @tool.call(it, expect["args"] + QUIET) }
    Evaluation::Verdict.new(fixture.to_s, expect, outcome).checks
  end
end
