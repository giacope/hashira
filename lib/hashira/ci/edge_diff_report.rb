# frozen_string_literal: true

module Hashira
  module CI
    class EdgeDiffReport
      def initialize(graph, io: $stdout)
        @graph = graph
        @io = io
      end

      def print(diff)
        diff.added.each { print_edge(it) }
        Improvement.new("Edges removed", io: @io).print(diff.removed)
      end

      private

      def print_edge(edge)
        @io.puts "NEW EDGE #{edge} — introduced by:"
        @graph.evidence_for(edge.from, edge.to).to_a.sort.each { @io.puts "  · #{it}" }
      end
    end
  end
end
