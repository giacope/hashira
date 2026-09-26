# frozen_string_literal: true

class Hashira::Report::HotspotTable
  TOP = 10
  HEADERS = %w[file Cog Dup Churn Rank].freeze

  def initialize(hotspots, top: TOP, io: $stdout)
    @hotspots = hotspots
    @top = top
    @io = io
  end

  def print
    return if ranked.empty?
    @io.puts("Hotspots — cost × churn (where refactoring pays the most):\n\n")
    Hashira::Report::Columns.new(HEADERS, ranked.map(&:cells), io: @io).print
    withheld
    legend
  end

  private

  def files = @_files ||= @hotspots.files

  def ranked = files.first(@top)

  def withheld
    rest = files.size - ranked.size
    @io.puts(Hashira::Report::Phrases.withheld(rest)) unless rest.zero?
  end

  def legend
    @io.puts("\nLegend: Cog cognitive complexity, Dup mass of the clones the file carries,")
    @io.puts("        Churn commits touching it, Rank (Cog+Dup) × Churn\n\n")
  end
end
