# frozen_string_literal: true

class Evaluation::Verdict
  BROKEN = { true => :acyclic, false => :cyclic }.freeze

  def initialize(name, expect, outcome)
    @name = name
    @expect = expect
    @outcome = outcome
  end

  def checks
    return [broken] unless @outcome.status.zero?
    [*edges, *absent, *cycles, *pairs, *cuts]
  end

  private

  def check(label, expected, actual)
    Evaluation::Check.of(Evaluation::Graphs::SUITE, "#{@name}: #{label}", expected, actual)
  end

  def broken = check("hashira exits cleanly", 0, @outcome.status)

  def reported = @_reported ||= @outcome.edges.keys.map { it.join(" -> ") }.sort

  def edges
    wanted = @expect["edges"]
    wanted ? [check("edges", wanted.sort, reported)] : []
  end

  def absent
    @expect.fetch("absent", []).map { check("edge #{it}", :absent, Evaluation::SEEN.fetch(reported.include?(it))) }
  end

  def knots = @outcome.kinds("cycle").map { it.dig("detail", "members").sort }.sort

  def cycles
    wanted = @expect["cycles"]
    wanted ? [check("cycles", wanted.map(&:sort).sort, knots)] : []
  end

  def pairs
    wanted = @expect["pairs"]
    paired = @outcome.kinds("bidirectional_association").map { it["package"] }.sort
    wanted ? [check("bidirectional associations", wanted.sort, paired)] : []
  end

  def cuts = @outcome.kinds("cycle").flat_map { cut(it.fetch("detail")) }

  def cut(detail)
    members = detail.fetch("members")
    chosen = detail.fetch("cut").map { [it["from"], it["to"], it["weight"]] }
    arcs = Evaluation::Arcs.new(inside(members))
    [
      check("cut of #{members.join(",")} leaves the knot", :acyclic, BROKEN.fetch(arcs.breaks?(chosen))),
      *optimal(members, chosen, arcs.minimum)
    ]
  end

  def optimal(members, chosen, optimum)
    [
      check("cut of #{members.join(",")} is a minimum feedback arc set", optimum, chosen.sum(&:last)),
      *fixture(members, optimum)
    ]
  end

  def fixture(members, optimum)
    wanted = @expect.dig("cut", members.min)
    wanted ? [check("brute force agrees with the fixture's hand count", wanted, optimum)] : []
  end

  def inside(members)
    @outcome.edges.filter_map { |(from, to), weight| [from, to, weight] if (members & [from, to]).size == 2 }
  end
end
