# frozen_string_literal: true

class Hashira::Report::MetricsTable
  def initialize(graph, io: $stdout)
    @graph = graph
    @io = io
  end

  LIMIT = 25

  def print
    heading
    kept.each { |package, metric| @io.puts(row(package, metric)) }
    note unless spared.empty?
    legend
  end

  private

  def ranked = @graph.metrics.sort_by { |_package, metric| metric.instability }

  def split = @split ||= (ranked.size > LIMIT ? ranked.partition { |_package, metric| !leaf?(metric) } : [ranked, []])

  def kept = split.first

  def spared = split.last

  def leaf?(metric) = metric.types <= 1 && metric.efferent.zero? && metric.afferent <= 1

  def note
    @io.puts("  + #{spared.size} single-type leaf packages (TC ≤ 1, Ca ≤ 1, Ce = 0) — hidden for brevity")
  end

  def heading
    @io.puts(format("%-12s %3s %3s %3s %5s  %-3s", *%w[package TC Ca Ce I Cyc]))
    @io.puts("-" * 40)
  end

  def row(package, metric)
    format(
      "%-12s %3d %3d %3d %5.2f  %-3s", package, *metric.to_h.values,
      (@graph.cycles.through?(package) ? "YES" : "-")
    )
  end

  def legend
    @io.puts("\nLegend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),")
    @io.puts("        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)\n\n")
  end
end
