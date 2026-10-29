# frozen_string_literal: true

class Hashira::Report::DependencyRow
  def initialize(graph, package)
    @graph = graph
    @package = package
  end

  def to_s
    edges = graph.edges
    outgoing = edges.outgoing(package).map { "#{it}(#{edges[package, it].evidence.size})" }
    format("  %-12s -> %-32s <- %s", package, listed(outgoing), listed(edges.incoming(package)))
  end
  private
  def listed(items) = items.empty? ? "(none)" : items.join(", ")

  attr_reader :graph, :package
end
