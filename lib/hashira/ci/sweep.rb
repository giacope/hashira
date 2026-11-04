# frozen_string_literal: true

class Hashira::CI::Sweep
  def edges(diff) = diff

  def findings(marks, recorded) = marks.against(recorded)

  def counts(edges, findings) = [edges, findings]
end
