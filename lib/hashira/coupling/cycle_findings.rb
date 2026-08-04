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
    finding(package: path.first, cycle: path, evidence: evidence(path), detail: detail(graph.cycles.weakest(path)))
  end

  def detail(weak)
    from, to = weak
    { weak:, weight: graph.weight(from, to) }
  end

  def evidence(path)
    path.each_cons(2).flat_map { |from, to| graph.evidence(from, to).to_a.first(2) }
  end
end
