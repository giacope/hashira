# frozen_string_literal: true

module Hashira
  module Diagram
    class Renderer
      def initialize(graph, format, io: $stdout)
        @graph = graph
        @format = format
        @io = io
      end

      def display
        edges = @graph.weighted_edges
        renderer = @format == :dot ? Dot.new(edges) : Mermaid.new(edges)
        @io.puts renderer.source
        0
      end
    end
  end
end
