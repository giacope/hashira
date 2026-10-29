# frozen_string_literal: true

class Hashira::CI::Slice
  SETTLED = Hashira::CI::Diff.new([], [], [])

  def edges(_diff) = SETTLED

  def findings(marks, recorded) = marks.against(recorded.within(marks)).unremoved

  def counts(_edges, findings) = [findings]
end
