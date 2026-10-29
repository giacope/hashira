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
    cycles = packages.cycles
    Hashira::Report::Columns.new(HEADERS, kept.map { |package, metric| row(package, metric, cycles) }, io: @io).print
    note unless spared.empty?
    more unless over.zero?
    @io.puts(LEGEND)
  end

  private

  def ranked = packages.to_h.sort_by { |_package, metric| metric }

  def split = @_split ||= (ranked.size > @top ? ranked.partition { |_package, metric| !metric.leaf? } : [ranked, []])

  def kept = split.first.first(@top)

  def spared = split.last

  def over = split.first.size - kept.size

  def note
    leaves = Hashira::Prose::Count.new(spared.size, "single-type leaf package")
    @io.puts("  + #{leaves} (TC ≤ 1, Ca ≤ 1, Ce = 0) — hidden for brevity")
  end

  def more = @io.puts(Hashira::Report::Withheld.new(over).to_s)

  def row(package, metric, cycles) = [package, *metric.to_a, cycles.path(package) ? "YES" : "-"]

  def packages = @_packages ||= @graph.packages
end
