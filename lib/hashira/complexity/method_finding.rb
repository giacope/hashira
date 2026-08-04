# frozen_string_literal: true

class Hashira::Complexity::MethodFinding
  KIND = "complexity"

  def initialize(score)
    @score = score
  end

  def to_finding
    Hashira::Analysis::Finding.new(kind: KIND, package: @score.subject, detail:, evidence:)
  end

  private

  def detail
    { cognitive: @score.cognitive, calls: @score.calls, site: "#{@score.file}:#{@score.line}", dominant: }
  end

  def evidence
    @score.increments.group_by(&:label).map { |label, incs| lines(label, incs) }
  end

  def lines(label, incs)
    lines = incs.map(&:line).uniq
    "#{label} +#{incs.sum(&:cost)} (line#{"s" if lines.size > 1} #{lines.join(", ")})"
  end

  def dominant
    @score.increments.group_by(&:label).transform_values { it.sum(&:cost) }.max_by(&:last).first
  end
end
