# frozen_string_literal: true

class Hashira::Diagram::Mermaid
  def initialize(edges, packages)
    @edges = edges
    @packages = packages
    @ids = {}
  end

  def source = "graph LR\n#{lines.join("\n")}"

  private

  def lines = @packages.map { "  #{declare(it)}" } + @edges.map { |from, to, weight| link(from, to, weight) }

  def link(from, to, weight) = "  #{id(from)} -->|#{weight}| #{id(to)}"

  def declare(package) = "#{id(package)}[#{package.to_json}]"

  def id(package) = @ids[package] ||= "p#{@ids.size}"
end
