# frozen_string_literal: true

class Hashira::CI::History
  def initialize(edges, marks, newer)
    @edges = edges
    @marks = marks
    @newer = newer
  end

  def judged(findings) = findings.reject { it.of?(@newer) }

  def unjudged(findings)
    unseen = findings.select { it.of?(@newer) }
    found = @newer.map { |kind| [kind, unseen.select { it.of?([kind]) }] }.reject { it.last.empty? }
    found.sort_by { |_kind, group| unseen.index(group.fetch(0)) }.map { |kind, group| "#{group.size} #{kind}" }
  end

  def drift(edges)
    added = edges.reject { @edges.include?(it.to_s) }
    Hashira::CI::Diff.new(added, @edges - edges.map(&:to_s), [])
  end

  def findings(compared, marks) = @marks.map { compared.findings(marks, it) }
end
