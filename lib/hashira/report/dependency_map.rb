# frozen_string_literal: true

module Hashira
  module Report
    class DependencyMap
      def initialize(graph, io: $stdout)
        @graph = graph
        @io = io
      end

      def print
        @io.puts "Dependencies (DependsUpon(refs) -> | <- UsedBy):"
        @graph.packages.sort.each { @io.puts row(it) }
      end

      private

      def row(package)
        format("  %-12s -> %-32s <- %s", package,
               list(depends_upon(package)), list(@graph.dependents_of(package)))
      end

      def depends_upon(package)
        @graph.dependencies_of(package).map { "#{it}(#{@graph.weight(package, it)})" }
      end

      def list(items) = items.empty? ? "(none)" : items.join(", ")
    end
  end
end
