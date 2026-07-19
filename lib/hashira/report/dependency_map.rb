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
        @graph.packages.sort.each { @io.puts row(_1) }
      end

      private

      def row(package)
        depends_upon = @graph.dependencies_of(package).map { "#{_1}(#{@graph.weight(package, _1)})" }.join(", ")
        used_by = @graph.dependents_of(package).join(", ")
        format("  %-12s -> %-32s <- %s", package,
               depends_upon.empty? ? "(none)" : depends_upon,
               used_by.empty? ? "(none)" : used_by)
      end
    end
  end
end
