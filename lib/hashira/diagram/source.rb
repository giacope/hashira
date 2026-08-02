# frozen_string_literal: true

class Hashira::Diagram::Source
  def initialize(graph, format, io: $stdout)
    @graph = graph
    @format = format
    @io = io
  end

  def print
    edges = @graph.weighted
    @io.puts((@format == :dot ? Hashira::Diagram::Dot.new(edges) : Hashira::Diagram::Mermaid.new(edges)).source)
    0
  end
end
