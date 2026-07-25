# frozen_string_literal: true

module Hashira
  module Report
    class HotspotTable
      TOP = 10
      ROW = "%-46s %5s %5s %6s %7s"

      def initialize(hotspots, io: $stdout)
        @hotspots = hotspots
        @io = io
      end

      def print
        return if ranked.empty?

        heading
        rows
        legend
      end

      private

      def ranked = @ranked ||= @hotspots.files.first(TOP)

      def rows = ranked.each { @io.puts format(ROW, *it.cells) }

      def heading
        @io.puts "Hotspots — cost × churn (where refactoring pays the most):\n\n"
        header = format(ROW, *%w[file Cog Dup Churn Rank])
        @io.puts header
        @io.puts "-" * header.length
      end

      def legend
        @io.puts "\nLegend: Cog cognitive complexity, Dup mass of the clones the file carries,"
        @io.puts "        Churn commits touching it, Rank (Cog+Dup) × Churn\n\n"
      end
    end
  end
end
