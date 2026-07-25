# frozen_string_literal: true

module Hashira
  module CI
    class RatchetReport
      def initialize(graph, findings, io: $stdout)
        @graph = graph
        @findings = findings
        @io = io
      end

      def print(edges, findings)
        return unchanged if quiet?(edges, findings)

        details(edges, findings)
        advice(edges, findings)
        1
      end

      private

      def quiet?(*diffs) = diffs.compact.all?(&:empty?)

      def unchanged
        @io.puts "Ratchet OK: #{@graph.edge_list.size} edges, #{@findings.size} findings, unchanged."
        0
      end

      def details(edges, findings)
        EdgeDiffReport.new(@graph, io: @io).print(edges)
        FindingDiffReport.new(@findings, io: @io).print(findings) if findings
      end

      def advice(*diffs)
        return unless diffs.compact.any?(&:worse?)

        @io.puts "\nRatchet FAILED. Either fix what regressed, or — if it is deliberate —"
        @io.puts "record the decision: update the baseline, or accept it with a reason."
      end
    end
  end
end
