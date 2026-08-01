# frozen_string_literal: true

class Hashira::CI::EdgeDiffReport
  def initialize(graph, io: $stdout)
    @graph = graph
    @io = io
  end

  def print(diff)
    diff.added.each { emit(it) }
    Hashira::CI::Improvement.new("Edges removed", io: @io).print(diff.removed)
  end

  private

  def emit(edge)
    @io.puts("NEW EDGE #{edge} — introduced by:")
    @graph.evidence(edge.from, edge.to).to_a.sort.each { @io.puts("  · #{it}") }
  end
end
