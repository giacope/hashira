# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Cycle < Hashira::Coupling::Rule
  KIND = "cycle"

  def list = graph.cycles.knots.map { knot(it.first, it, graph.cycles) }

  private

  def knot(key, members, cycles)
    found = cycles.cut(members)
    cut = found.edges.map { pledged(*it) }
    detail = { members:, folded: folded(members) }.merge(cut:, exact: found.exact?)
    finding(package: key, cycle: cycles.path(key), evidence: evidence(cut), detail:)
  end

  def pledged(from, to, weight)
    edge = weighed(from, to, weight)
    guarantees = graph.guarantees(from, to).sort
    guarantees.empty? ? edge : edge.merge(guarantees:)
  end

  def folded(members) = (members & graph.folds.map { it[:to] }).reject { graph.unfolded.cycles.through?(it) }

  def evidence(cut) = cut.flat_map { graph.evidence(it[:from], it[:to]).to_a.sort }
end
