# frozen_string_literal: true

class Hashira::CI::Sweep
  def initialize(baseline)
    @baseline = baseline
  end

  def edges(diff) = diff

  def findings(marks) = Hashira::CI::Comparison.new(marks, @baseline.marks).diff

  def counts(edges, findings) = [edges, findings]
end
