# frozen_string_literal: true

class Hashira::Report::MetricsTable
  def initialize(graph, io: $stdout)
    @graph = graph
    @io = io
  end

  LIMIT = 25
  HEADERS = %w[package TC Ca Ce I Cyc].freeze

  def print
    Hashira::Report::Columns.new(HEADERS, kept.map { |package, metric| row(package, metric) }, io: @io).print
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

  def row(package, metric) = [package, *metric.cells, cyc(package)]

  def cyc(package) = @graph.cycles.through?(package) ? "YES" : "-"

  def legend
    @io.puts("\nLegend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),")
    @io.puts("        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)\n\n")
  end
end
