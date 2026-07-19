# frozen_string_literal: true

module Hashira
  module Analysis
    class Graph
      def initialize(project, trees, census)
        @census = census
        @edge_map = EdgeMap.new(project, census)
        trees.each { |file, tree| @edge_map.record(file, tree) }
      end

      def packages = @census.packages

      def dependencies_of(package) = dependencies[package].to_a.sort

      def dependents_of(package) = packages.select { dependencies[_1].include?(package) }.sort

      def edge_list
        dependencies.sort.flat_map { |from, tos| tos.sort.map { Edge.new(from:, to: _1) } }
      end

      def weighted_edges
        edge_list.map do |edge|
          from, to = edge.deconstruct
          [from, to, weight(from, to)]
        end
      end

      def evidence_for(from, to) = @edge_map.evidence[[from, to]]

      def metric_for(package)
        Metric.new(type_count: @census.type_count[package],
                   afferent: dependents_of(package).size,
                   efferent: dependencies[package].size)
      end

      def metrics = packages.to_h { [_1, metric_for(_1)] }

      def sdp_violations = SdpCheck.new(dependencies, metrics).violations

      def cyclic?(package) = !!cycle_path(package)

      def weight(from, to) = evidence_for(from, to).size

      def cycle_path(package) = CycleSearch.new(dependencies, package).path

      def weakest_edge(path)
        path.each_cons(2).min_by { |from, to| weight(from, to) }
      end

      private

      def dependencies = @edge_map.dependencies
    end
  end
end
