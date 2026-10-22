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
    kept.each { @io.puts(Hashira::Report::DependencyRow.new(@graph, it)) }
    @io.puts(Hashira::Report::Withheld.new(over).to_s) if over.positive?
    loners unless split.last.empty?
    @io.puts
  end

  private

  def split = @_split ||= @graph.packages.partition { degree(it).positive? }

  def ranked = split.first.sort_by { [-degree(it), it] }

  def kept = ranked.first(@top)

  def over = split.first.size - kept.size

  def loners = @io.puts("  + #{Hashira::Report::Count.new(split.last.size, "package")} with no edges either way")

  def degree(package) = @graph.outgoing(package).size + @graph.incoming(package).size
end

Hashira::Report::DependencyRow =
  Data.define(:graph, :package) do
    def to_s
      outgoing = graph.outgoing(package).map { "#{it}(#{graph.weight(package, it)})" }
      format("  %-12s -> %-32s <- %s", package, listed(outgoing), listed(graph.incoming(package)))
    end
    private
    def listed(items) = items.empty? ? "(none)" : items.join(", ")
  end
