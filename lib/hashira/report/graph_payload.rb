# frozen_string_literal: true

module Hashira
  module Report
    class GraphPayload
      def initialize(graph)
        @graph = graph
      end

      def to_h = { packages:, edges: }

      private

      def packages
        @graph.metrics.sort_by { |_package, metric| metric.instability }
                      .to_h do |package, metric|
          [package,
           metric.to_h.merge(cyclic: @graph.cyclic?(package))]
        end
      end

      def edges
        @graph.weighted_edges.map do |from, to, weight|
          { from:, to:, weight:, refs: @graph.evidence_for(from, to).to_a.sort }
        end
      end
    end
  end
end
