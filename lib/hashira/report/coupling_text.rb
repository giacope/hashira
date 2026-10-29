# frozen_string_literal: true

class Hashira::Report::CouplingText
  def initialize(graph, paths, listing, page)
    @graph = graph
    @paths = paths
    @listing = listing
    @page = page
  end

  def print
    header
    @page.table(Hashira::Report::MetricsTable, @graph)
    @page.table(Hashira::Report::DependencyMap, @graph)
    folded(@graph.folds)
  end

  private

  def folded(folds)
    return if folds.empty?
    @page.puts("Folded (packages joined to the one they belong to):")
    folds.each { @page.puts("  #{it}") }
    @page.puts("")
  end

  def header
    packages = @graph.packages.size
    @page.puts(banner(@graph.packaging, packages))
    caveat if packages == 1
  end

  def banner(grouping, packages)
    "Package (#{grouping}) metrics for #{@paths}  " \
      "(#{count(packages, "package")}, #{count(@listing.to_a.size, "file")})\n\n"
  end

  def count(number, noun) = Hashira::Prose::Count.new(number, noun).to_s

  def caveat
    @page.puts(
      "Only one package found — there are no boundaries to analyze. " \
        "Pass subdirectories to set them (e.g. hashira lib/gem/*/).\n\n"
    )
  end
end
