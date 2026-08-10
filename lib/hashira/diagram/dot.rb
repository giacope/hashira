# frozen_string_literal: true

class Hashira::Diagram::Dot
  def initialize(edges, packages)
    @edges = edges
    @packages = packages
  end

  def source = "digraph hashira {\n  rankdir=LR;\n#{lines.join("\n")}\n}"

  private

  def lines = @packages.map { %(  "#{it}";) } + @edges.map { |from, to, weight| link(from, to, weight) }

  def link(from, to, weight) = %(  "#{from}" -> "#{to}" [label="#{weight}"];)
end
