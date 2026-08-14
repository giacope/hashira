# frozen_string_literal: true

class Hashira::Report::MetricsTable
  TOP = 25

  def initialize(graph, top: TOP, io: $stdout)
    @graph = graph
    @top = top
    @io = io
  end

  HEADERS = %w[package TC Ca Ce I Cyc].freeze

  def print
    Hashira::Report::Columns.new(HEADERS, kept.map { |package, metric| row(package, metric) }, io: @io).print
    note unless spared.empty?
    more unless over.zero?
    legend
  end

  private

  def ranked = @graph.metrics.sort_by { |_package, metric| metric.order }

  def split = @_split ||= (ranked.size > @top ? ranked.partition { |_package, metric| !leaf?(metric) } : [ranked, []])

  def kept = split.first.first(@top)

  def spared = split.last

  def over = split.first.size - kept.size

  def leaf?(metric) = metric.types <= 1 && metric.efferent.zero? && metric.afferent <= 1

  def note = @io.puts("  + #{leaves} (TC ≤ 1, Ca ≤ 1, Ce = 0) — hidden for brevity")

  def leaves = Hashira::Report::Phrases.count(spared.size, "single-type leaf package")

  def more = @io.puts("  … and #{over} more — raise the cap with --top, or read them all with --json")

  def row(package, metric) = [package, *metric.cells, cyc(package)]

  def cyc(package) = @graph.cycles.through?(package) ? "YES" : "-"

  def legend
    @io.puts("\nLegend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),")
    @io.puts("        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)\n\n")
  end
end
