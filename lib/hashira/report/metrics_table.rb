# frozen_string_literal: true

class Hashira::Report::MetricsTable
  TOP = 25

  def initialize(graph, top: TOP, io: $stdout)
    @graph = graph
    @top = top
    @io = io
  end

  HEADERS = %w[package TC Ca Ce I Cyc].freeze

  LEGEND = <<~TEXT

    Legend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),
            I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)

  TEXT

  def print
    Hashira::Report::Columns.new(HEADERS, kept.map { |package, metric| row(package, metric) }, io: @io).print
    note unless spared.empty?
    more unless over.zero?
    @io.puts(LEGEND)
  end

  private

  def ranked = @graph.metrics.sort_by { |_package, metric| metric.order }

  def split = @_split ||= (ranked.size > @top ? ranked.partition { |_package, metric| !leaf?(metric) } : [ranked, []])

  def kept = split.first.first(@top)

  def spared = split.last

  def over = split.first.size - kept.size

  def leaf?(metric) = metric.types <= 1 && metric.efferent.zero? && metric.afferent <= 1

  def note
    leaves = Hashira::Report::Count.new(spared.size, "single-type leaf package")
    @io.puts("  + #{leaves} (TC ≤ 1, Ca ≤ 1, Ce = 0) — hidden for brevity")
  end

  def more = @io.puts(Hashira::Report::Withheld.new(over).to_s)

  def row(package, metric) = [package, *metric.cells, @graph.cycles.through?(package) ? "YES" : "-"]
end
