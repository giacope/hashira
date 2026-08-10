# frozen_string_literal: true

class Hashira::Report::HotspotTable
  TOP = 10
  HEADERS = %w[file Cog Dup Churn Rank].freeze

  def initialize(hotspots, io: $stdout)
    @hotspots = hotspots
    @io = io
  end

  def print
    return if ranked.empty?
    @io.puts("Hotspots — cost × churn (where refactoring pays the most):\n\n")
    Hashira::Report::Columns.new(HEADERS, ranked.map(&:cells), io: @io).print
    legend
  end

  private

  def ranked = @ranked ||= @hotspots.files.first(TOP)

  def legend
    @io.puts("\nLegend: Cog cognitive complexity, Dup mass of the clones the file carries,")
    @io.puts("        Churn commits touching it, Rank (Cog+Dup) × Churn\n\n")
  end
end
