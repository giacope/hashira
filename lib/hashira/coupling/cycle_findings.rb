# frozen_string_literal: true

require_relative "rule"

class Hashira::Coupling::CycleFindings < Hashira::Coupling::Rule
  KIND = "cycle"

  def list
    loops.map { entry(it) }
  end

  private

  def loops
    cycles = graph.cycles
    graph.packages.select { cycles.through?(it) }.sort.map { cycles.path(it) }.uniq { it[..-2].sort }
  end

  def entry(path)
    finding(
      package: path.first, cycle: path, evidence: evidence(path),
      sources: sources(path), detail: detail(graph.cycles.weakest(path))
    )
  end

  def detail(weak) = { weak:, weight: graph.weight(link(weak)) }

  def link(pair) = Hashira::Coupling::Edge.new(*pair)

  def evidence(path)
    path.each_cons(2).flat_map { graph.evidence(link(it)).to_a.first(2) }
  end

  def sources(path)
    path.each_cons(2).flat_map { graph.sources(link(it)) }
  end
end
