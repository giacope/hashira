# frozen_string_literal: true

class Hashira::CI::EdgeChanges
  def initialize(graph, io: $stdout)
    @graph = graph
    @io = io
  end

  def print(diff) = diff.told(self)

  def list(added, _worsened, removed)
    added.each { emit(it) }
    Hashira::CI::Improvement.new("Edges removed", io: @io).print(removed)
  end

  private

  def emit(edge)
    @io.puts("NEW EDGE #{edge} — introduced by:")
    edge.evidence.sort.each { @io.puts("  · #{it}") }
  end
end
