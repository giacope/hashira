# frozen_string_literal: true

require "json"

module Hashira
  module CI
    class Ratchet
      def initialize(graph, baseline_path, io: $stdout)
        @graph = graph
        @baseline_path = baseline_path
        @io = io
      end

      SCHEMA_VERSION = 1

      def update
        edges = @graph.edge_list.map(&:to_s)
        File.write(@baseline_path, JSON.pretty_generate(payload(edges)) << "\n")
        @io.puts "Baseline updated: #{edges.size} edges."
        0
      end

      def check
        added, removed = diff(@graph.edge_list)
        EdgeDiffReport.new(@graph, io: @io).print(added, removed)
      end

      private

      def payload(edges)
        accepted = Accepted.load(File.exist?(@baseline_path) ? @baseline_path : nil).entries
        base = { version: SCHEMA_VERSION, edges: }
        accepted.empty? ? base : base.merge(accepted:)
      end

      def diff(edges)
        raise Error, "no baseline at #{@baseline_path} — run --update-baseline first" unless File.exist?(@baseline_path)

        baseline = JSON.parse(File.read(@baseline_path)).fetch("edges")
        [edges.reject { baseline.include?(_1.to_s) }, baseline - edges.map(&:to_s)]
      end
    end
  end
end
