# frozen_string_literal: true

class Hashira::Report::Text
  def initialize(view, io: $stdout)
    @view = view
    @io = io
  end

  def print
    coupling if @view.graph
    complexity if @view.complexity
    hotspots if @view.hotspots
    findings
    0
  end

  private

  def coupling
    graph = @view.graph
    header(graph)
    Hashira::Report::MetricsTable.new(graph, io: @io).print
    Hashira::Report::DependencyMap.new(graph, io: @io).print
    folded(graph.folds)
  end

  def folded(folds)
    return if folds.empty?
    @io.puts("Folded (single-type classes joined to their base or domain):")
    folds.each { @io.puts("  #{it[:from]} -> #{it[:to]} (#{it[:via]})") }
    @io.puts
  end

  def complexity = Hashira::Report::ComplexityTable.new(@view.complexity, io: @io).print

  def hotspots = Hashira::Report::HotspotTable.new(@view.hotspots, io: @io).print

  def header(graph)
    packages = graph.packages.size
    @io.puts(banner(packages))
    caveat if packages == 1
  end

  def banner(packages)
    "Package (layer) metrics for #{@view.project.label}  (#{packages} packages, #{total} files)\n\n"
  end

  def total = @view.project.files.size

  def caveat
    @io.puts(
      "Only one package found — there are no boundaries to analyze. " \
        "Pass subdirectories to set them (e.g. hashira lib/gem/*/).\n\n"
    )
  end

  def findings
    all = @view.findings.all
    @io.puts("Findings (#{all.size}):")
    list(all)
    accepted
    @io.puts("\n  Full evidence + machine format: hashira --json") unless all.empty?
  end

  def list(all)
    return @io.puts("  none ✓ — structure is healthy") if all.empty?
    all.each { Hashira::Report::FindingLines.new(it, indent: "  ", io: @io).emit }
  end

  def accepted
    accepted = @view.findings.accepted
    return if accepted.empty?
    @io.puts("\nAccepted (#{accepted.size}):")
    accepted.each { |finding, reason| @io.puts("  ~ #{finding.kind}/#{finding.package} — #{reason}") }
  end
end
