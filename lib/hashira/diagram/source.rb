# frozen_string_literal: true

class Hashira::Diagram::Source
  def initialize(graph, format, io: $stdout)
    @graph = graph
    @format = format
    @io = io
  end

  def print = @io.puts(drawing.new(@graph.weighted, @graph.packages.sort).source)

  def status = 0

  private

  def drawing = @format == :dot ? Hashira::Diagram::Dot : Hashira::Diagram::Mermaid
end
