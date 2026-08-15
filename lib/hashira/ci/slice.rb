# frozen_string_literal: true

class Hashira::CI::Slice
  SETTLED = Hashira::CI::Diff.new(added: [], removed: [])

  def initialize(baseline)
    @baseline = baseline
  end

  def edges(_diff) = SETTLED

  def findings(scored) = Hashira::CI::Comparison.new(scored, seen(scored)).diff

  def seen(scored) = @baseline.findings.slice(*scored.keys)

  def counts(_edges, findings) = [findings]
end
