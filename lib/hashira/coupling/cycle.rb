# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::Cycle < Hashira::Coupling::Rule
  KIND = "cycle"

  def list = graph.cycles.knots.map { entry(it) }

  private

  def entry(members) = knot(members.first, members, graph.cycles)

  def knot(key, members, cycles)
    cut = cycles.cut(members).map { |from, to, weight| { from:, to:, weight: } }
    finding(package: key, cycle: cycles.path(key), evidence: evidence(cut), detail: { members:, cut: })
  end

  def evidence(cut) = cut.flat_map { graph.evidence(it[:from], it[:to]).to_a.sort }
end
