# frozen_string_literal: true

class Hashira::Report::DependencyMap
  def initialize(graph, io: $stdout)
    @graph = graph
    @io = io
  end

  def print
    @io.puts("Dependencies (DependsUpon(refs) -> | <- UsedBy):")
    @graph.packages.sort.each { @io.puts(row(it)) }
    @io.puts
  end

  private

  def row(package)
    format("  %-12s -> %-32s <- %s", package, list(outgoing(package)), list(@graph.incoming(package)))
  end

  def outgoing(package)
    @graph.departures(package).map { |to, weight| "#{to}(#{weight})" }
  end

  def list(items) = items.empty? ? "(none)" : items.join(", ")
end
