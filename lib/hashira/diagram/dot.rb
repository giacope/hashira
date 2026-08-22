# frozen_string_literal: true

class Hashira::Diagram::Dot
  ESCAPED = /["\\]/

  def initialize(edges, packages)
    @edges = edges
    @packages = packages
  end

  def source = "digraph hashira {\n  rankdir=LR;\n#{lines.join("\n")}\n}"

  private

  def lines = @packages.map { "  #{quote(it)};" } + @edges.map { |from, to, weight| link(from, to, weight) }

  def link(from, to, weight) = "  #{quote(from)} -> #{quote(to)} [label=#{quote(weight)}];"

  def quote(text) = %("#{text.to_s.gsub(ESCAPED) { "\\#{it}" }.gsub("\n", "\\n")}")
end
