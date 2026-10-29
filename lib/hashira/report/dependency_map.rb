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

  def loners = @io.puts("  + #{Hashira::Prose::Count.new(split.last.size, "package")} with no edges either way")

  def degree(package) = @graph.outgoing(package).size + @graph.incoming(package).size
end
