# frozen_string_literal: true

class Hashira::Report::GraphPayload
  def initialize(graph)
    @graph = graph
  end

  def to_h = { packages: ranked, edges:, folds: packages.folds.map(&:to_h) }

  private

  def ranked
    cycles = packages.cycles
    sorted = packages.to_h.sort_by { |_package, metric| metric.instability }
    sorted.to_h { |package, metric| [package, metric.to_h.merge(cyclic: !cycles.path(package).nil?)] }
  end

  def packages = @_packages ||= @graph.packages

  def edges
    @graph.edges.to_a.map do |edge|
      from, to, weight = edge.to_a
      { from:, to:, weight: }.merge(refs: edge.evidence.sort)
    end
  end
end
