# frozen_string_literal: true

require "json"

module Hashira
  module Report
    class Json
      def initialize(graph, findings, io: $stdout)
        @graph = graph
        @findings = findings
        @io = io
      end

      def print
        @io.puts JSON.pretty_generate(packages:, edges:, findings: @findings.all.map(&:to_h),
                                      accepted: accepted_entries)
        0
      end

      private

      def accepted_entries
        @findings.accepted.map { |finding, reason| finding.to_h.merge(reason:) }
      end

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
