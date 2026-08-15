# frozen_string_literal: true

class Hashira::CI::Sweep
  def initialize(baseline)
    @baseline = baseline
  end

  def edges(diff) = diff

  def findings(scored) = Hashira::CI::Comparison.new(scored, @baseline.findings).diff

  def counts(edges, findings) = [edges, findings]
end
