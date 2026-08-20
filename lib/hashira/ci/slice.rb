# frozen_string_literal: true

class Hashira::CI::Slice
  SETTLED = Hashira::CI::Diff.new(added: [], removed: [])

  def initialize(baseline)
    @baseline = baseline
  end

  def edges(_diff) = SETTLED

  def findings(marks) = Hashira::CI::Comparison.new(marks, seen(marks, traces(marks))).diff.with(removed: [])

  def counts(_edges, findings) = [findings]

  private

  def traces(marks) = marks.each_value.filter_map(&:trace)

  def seen(marks, traces) = @baseline.marks.select { |key, mark| marks.key?(key) || traces.include?(mark.trace) }
end
