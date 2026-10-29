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

  def list
    cycles = packages.cycles
    cycles.knots.map { knot(it, cycles) }
  end

  private

  def knot(members, cycles)
    found = cycles.cut(members)
    ties = found.edges
    ring = Ring.new(members, packages.folded(members), Hashira::Coupling::Ties.new(ties, pledges(ties)), found.exact?)
    finding(looped(members.first, cycles), ring, proof(ties))
  end

  def proof(ties)
    Hashira::Analysis::Finding::Proof.new(ties.flat_map { |from, to, _weight| edges[from, to].evidence.sort })
  end

  def pledges(ties) = ties.to_h { |from, to, _weight| [[from, to], edges[from, to].guarantees.sort] }
end
