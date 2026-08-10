# frozen_string_literal: true

class Hashira::Report::Text
  FINDINGS = 25

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
    table(Hashira::Report::MetricsTable, graph)
    Hashira::Report::DependencyMap.new(graph, io: @io).print
    folded(graph.folds)
  end

  def folded(folds)
    return if folds.empty?
    @io.puts("Folded (single-type classes joined to their base or domain):")
    folds.each { @io.puts("  #{it[:from]} -> #{it[:to]} (#{it[:via]})") }
    @io.puts
  end

  def table(kind, subject) = kind.new(subject, top: @view.top || kind::TOP, io: @io).print

  def complexity = table(Hashira::Report::ComplexityTable, @view.complexity)

  def hotspots = table(Hashira::Report::HotspotTable, @view.hotspots)

  def header(graph)
    packages = graph.packages.size
    @io.puts(banner(packages))
    caveat if packages == 1
  end

  def banner(packages)
    "Package (layer) metrics for #{@view.project.label}  (#{count(packages, "package")}, #{count(total, "file")})\n\n"
  end

  def count(number, noun) = Hashira::Report::Phrases.count(number, noun)

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
    shown = all.first(@view.top || FINDINGS)
    shown.each { Hashira::Report::FindingLines.new(it, indent: "  ", io: @io).emit }
    elided(all.size - shown.size)
  end

  def elided(rest)
    return if rest.zero?
    @io.puts("  … and #{rest} more — raise the cap with --top, or read them all with --json")
  end

  def accepted
    accepted = @view.findings.accepted
    return if accepted.empty?
    @io.puts("\nAccepted (#{accepted.size}):")
    accepted.each { |finding, reason| @io.puts("  ~ #{finding.kind}/#{finding.package} — #{reason}") }
  end
end
