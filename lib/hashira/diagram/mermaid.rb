# frozen_string_literal: true

class Hashira::Diagram::Mermaid
  def initialize(edges)
    @edges = edges
    @nodes = {}
  end

  def source
    "graph LR\n#{@edges.map { |from, to, weight| "  #{node(from)} -->|#{weight}| #{node(to)}" }.join("\n")}"
  end

  private

  def node(package)
    @nodes[package] ||= "#{package.gsub(/\W/, "_")}[\"#{package}\"]"
  end
end
