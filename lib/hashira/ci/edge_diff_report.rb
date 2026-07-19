# frozen_string_literal: true

module Hashira
  module CI
    class EdgeDiffReport
      def initialize(graph, io: $stdout)
        @graph = graph
        @io = io
      end

      def print(added, removed)
        return print_unchanged if added.empty? && removed.empty?

        print_added(added)
        print_removed(removed)
        1
      end

      private

      def print_unchanged
        @io.puts "Ratchet OK: #{@graph.edge_list.size} edges, unchanged."
        0
      end

      def print_added(added)
        return if added.empty?

        added.each { print_edge(_1) }
        @io.puts "\nRatchet FAILED. Either decouple, or if the new edge is a deliberate"
        @io.puts "design decision, update the baseline and say why in the commit."
      end

      def print_edge(edge)
        @io.puts "NEW EDGE #{edge} — introduced by:"
        @graph.evidence_for(edge.from, edge.to).to_a.sort.each { @io.puts "  · #{_1}" }
      end

      def print_removed(removed)
        return if removed.empty?

        @io.puts "Edges removed (improvement!): #{removed.join(", ")}"
        @io.puts "Lock it in: hashira --update-baseline"
      end
    end
  end
end
