# frozen_string_literal: true

class Hashira::Coupling::Ties
  ROSTER = 6

  def initialize(edges, pledges = {})
    @edges = edges
    @pledges = pledges
  end

  def to_a
    @edges.map do |from, to, weight|
      edge = { from:, to:, weight: }
      found = pledged([from, to])
      found.empty? ? edge : edge.merge(guarantees: found)
    end
  end

  def total = @edges.sum(&:last)

  def cheapest(exact)
    shown = @edges.first(ROSTER).map { link(it) }.join(", ")
    rest = @edges.size - ROSTER
    tail = rest.positive? ? " and #{rest} more (#{total} refs in all)" : ""
    "The cheapest cut#{" found" if exact == false} is #{shown}#{tail}."
  end

  def guarded
    held = @edges.reject { pledged(it.first(2)).empty? }
    return "" if held.empty?
    " #{holders(held)} a dependent: option (#{pledge(held)}) — cutting #{held.one? ? "it" : "one"} drops what " \
      "deleting the owner does to its records, so hand that to an object above both packages first."
  end

  def outward
    shown = @edges.first(ROSTER).map { link(it) }
    rest = @edges.size - shown.size
    listed = rest.positive? ? [*shown, Hashira::Prose::Count.new(rest, "more edge").to_s] : shown
    [listed[..-2].join(", "), listed.last].reject(&:empty?).join(" and ")
  end

  private

  def pledged(ends) = @pledges.fetch(ends, [])

  def link((from, to, weight)) = "#{from} -> #{to} (#{weight} ref#{"s" unless weight == 1})"

  def arrow((from, to)) = "#{from} -> #{to}"

  def holders(held) = held.one? ? "#{arrow(held.fetch(0))} carries" : "#{held.size} of these edges carry"

  def pledge(held)
    edge = held.fetch(0)
    site, said = pledged(edge.first(2)).fetch(0).split(": ", 2)
    lead = held.one? ? "" : "#{arrow(edge)}: "
    "#{lead}#{said} at #{site}#{", …" if held.sum { pledged(it.first(2)).size } > 1}"
  end
end
