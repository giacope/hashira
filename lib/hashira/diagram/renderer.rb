# frozen_string_literal: true

class Hashira::Diagram::Renderer
  def initialize(graph, format, io: $stdout)
    @graph = graph
    @format = format
    @io = io
  end

  def display
    edges = @graph.weighted
    @io.puts((@format == :dot ? Hashira::Diagram::Dot.new(edges) : Hashira::Diagram::Mermaid.new(edges)).source)
    0
  end
end
