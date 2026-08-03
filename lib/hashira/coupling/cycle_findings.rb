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
    package = path.first
    finding(
      package:, cycle: path, evidence: evidence(path),
      message: message(package, path, graph.cycles.weakest(path))
    )
  end

  def message(package, path, weak_edge)
    from, to = weak_edge
    weight = graph.weight(from, to)
    "#{package} can reach itself: #{path.join(" -> ")} — any change may ripple back " \
      "around. The lightest edge on this cycle is #{from} -> #{to} " \
      "(#{weight} ref#{"s" unless weight == 1})."
  end

  def evidence(path)
    path.each_cons(2).flat_map { |from, to| graph.evidence(from, to).to_a.first(2) }
  end
end
