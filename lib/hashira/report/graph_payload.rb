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

  def edges
    @graph.weighted.map do |from, to, weight|
      { from:, to:, weight:, refs: @graph.evidence(from, to).to_a.sort }
    end
  end
end
