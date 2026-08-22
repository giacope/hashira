# frozen_string_literal: true

class Hashira::Report::GraphPayload
  def initialize(graph)
    @graph = graph
  end

  def to_h = { packages:, edges:, folds: @graph.folds }

  private

  def packages
    ranked.to_h { |package, metric| [package, metric.to_h.merge(cyclic: @graph.cycles.through?(package))] }
  end

  def ranked = @graph.metrics.sort_by { |_package, metric| metric.instability }

  def edges = @graph.edges.map { entry(it) }

  def entry(edge)
    { from: edge.from, to: edge.to, weight: @graph.weight(edge) }.merge(refs: @graph.refs(edge))
  end
end
