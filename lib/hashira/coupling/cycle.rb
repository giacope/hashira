# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Cycle < Hashira::Coupling::Rule
  KIND = "cycle"

  class Ring
    ROSTER = 6

    def initialize(members, folded, ties, exact)
      @members = members
      @folded = folded
      @ties = ties
      @exact = exact
    end

    def to_h = { members: @members, folded: @folded, cut: @ties.to_a, exact: @exact }

    def phrase(_package)
      "#{roster(@members)} depend on each other in a cycle#{joined} — " \
        "any change may ripple back around. #{@ties.cheapest(@exact)}#{@ties.guarded}"
    end

    private

    def roster(members)
      shown = members.first(ROSTER)
      rest = members.size - shown.size
      rest.positive? ? "#{shown.join(", ")} and #{rest} more" : "#{shown[..-2].join(", ")} and #{shown.last}"
    end

    def joined
      return "" if @folded.empty?
      " (#{@folded.one? ? "#{@folded.fetch(0)} is" : "#{roster(@folded)} are"} in it only through folded types)"
    end
  end

  def list = graph.knots.map { knot(it, graph.cycles) }

  private

  def knot(members, cycles)
    found = cycles.cut(members)
    edges = found.edges
    ring = Ring.new(members, folded(members), Hashira::Coupling::Ties.new(edges, pledges(edges)), found.exact?)
    finding(
      looped(members.first, cycles), ring,
      Hashira::Analysis::Finding::Proof.new(edges.flat_map { |from, to, _weight| graph.evidence(from, to).to_a.sort })
    )
  end

  def pledges(edges) = edges.to_h { |from, to, _weight| [[from, to], graph.guarantees(from, to).sort] }

  def folded(members) = (members & graph.folds.map { it.to_h[:to] }).reject { graph.unfolded.cycles.through?(it) }
end
