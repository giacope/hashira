# frozen_string_literal: true

class Hashira::Diagram::Source
  def initialize(graph, format, io: $stdout)
    @graph = graph
    @format = format
    @io = io
  end

  def print = @io.puts(drawing.new(edges.to_a.map(&:to_a), packages.to_a.sort).source)

  def status = 0

  private

  def drawing = @format == :dot ? Hashira::Diagram::Dot : Hashira::Diagram::Mermaid

  def edges = @graph.edges

  def packages = @graph.packages
end
