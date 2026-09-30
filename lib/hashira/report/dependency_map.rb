# frozen_string_literal: true

class Hashira::Report::DependencyMap
  TOP = 25

  def initialize(graph, top: TOP, io: $stdout)
    @graph = graph
    @top = top
    @io = io
  end

  def print
    @io.puts("Dependencies (DependsUpon(refs) -> | <- UsedBy):")
    kept.each { @io.puts(row(it)) }
    @io.puts(Hashira::Report::Phrases.withheld(over)) if over.positive?
    loners unless split.last.empty?
    @io.puts
  end

  private

  def split = @_split ||= @graph.packages.partition { degree(it).positive? }

  def ranked = split.first.sort_by { [-degree(it), it] }

  def kept = ranked.first(@top)

  def over = split.first.size - kept.size

  def degree(package) = @graph.outgoing(package).size + @graph.incoming(package).size

  def loners = @io.puts("  + #{Hashira::Report::Phrases.count(split.last.size, "package")} with no edges either way")

  def row(package)
    format("  %-12s -> %-32s <- %s", package, list(outgoing(package)), list(@graph.incoming(package)))
  end

  def outgoing(package)
    @graph.outgoing(package).map { "#{it}(#{@graph.weight(package, it)})" }
  end

  def list(items) = items.empty? ? "(none)" : items.join(", ")
end
