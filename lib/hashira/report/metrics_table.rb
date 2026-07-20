# frozen_string_literal: true

module Hashira
  module Report
    class MetricsTable
      def initialize(graph, io: $stdout)
        @graph = graph
        @io = io
      end

      def print
        heading
        by_instability.each { |package, metric| @io.puts row(package, metric) }
        legend
      end

      private

      def by_instability = @graph.metrics.sort_by { |_package, metric| metric.instability }

      def heading
        @io.puts format("%-12s %3s %3s %3s %5s  %-3s", *%w[package TC Ca Ce I Cyc])
        @io.puts "-" * 40
      end

      def row(package, metric)
        cyclic = @graph.cyclic?(package) ? "YES" : "-"
        format("%-12s %3d %3d %3d %5.2f  %-3s", package, *metric.to_h.values, cyclic)
      end

      def legend
        @io.puts "\nLegend: TC total types, Ca afferent (incoming), Ce efferent (outgoing),"
        @io.puts "        I=Ce/(Ce+Ca) instability (0=maximally stable, 1=maximally unstable)\n\n"
      end
    end
  end
end
