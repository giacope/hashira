# frozen_string_literal: true

class Hashira::Diagram::Source
  def initialize(graph, format, io: $stdout)
    @graph = graph
    @format = format
    @io = io
  end

  def print
    @io.puts(drawing.new(@graph.weighted, @graph.packages.sort).source)
    0
  end

  private

  def drawing = @format == :dot ? Hashira::Diagram::Dot : Hashira::Diagram::Mermaid
end
