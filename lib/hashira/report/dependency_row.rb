# frozen_string_literal: true

class Hashira::Report::DependencyRow
  def initialize(graph, package)
    @graph = graph
    @package = package
  end

  def to_s
    outgoing = graph.outgoing(package).map { "#{it}(#{graph.weight(package, it)})" }
    format("  %-12s -> %-32s <- %s", package, listed(outgoing), listed(graph.incoming(package)))
  end
  private
  def listed(items) = items.empty? ? "(none)" : items.join(", ")

  attr_reader :graph, :package
end
