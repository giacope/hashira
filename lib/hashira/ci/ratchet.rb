# frozen_string_literal: true

module Hashira
  module CI
    class Ratchet
      def initialize(graph, findings, baseline_path, io: $stdout)
        @graph = graph
        @findings = findings
        @baseline = Baseline.load(baseline_path)
        @io = io
      end

      def update
        @baseline.write(edge_signatures, finding_signatures)
        @io.puts "Baseline updated: #{edge_signatures.size} edges, #{finding_signatures.size} findings."
        0
      end

      def check
        raise Error, "no baseline at #{@baseline.path} — run --update-baseline first" unless @baseline.exist?

        RatchetReport.new(@graph, @findings, io: @io).print(edge_diff, finding_diff)
      end

      private

      def edge_signatures = @graph.edge_list.map(&:to_s)

      def finding_signatures = @findings.map(&:signature).uniq.sort

      def edge_diff = Diff.new(added: new_edges, removed: @baseline.edges - edge_signatures)

      def new_edges = @graph.edge_list.reject { @baseline.edges.include?(it.to_s) }

      def finding_diff
        Diff.between(finding_signatures, @baseline.findings) if @baseline.ratchets_findings?
      end
    end
  end
end
