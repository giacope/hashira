# frozen_string_literal: true

class Hashira::Diagram::Dot
  def initialize(edges)
    @edges = edges
  end

  def source
    "digraph hashira {\n  rankdir=LR;\n#{@edges.map do |from, to, weight|
      %(  "#{from}" -> "#{to}" [label="#{weight}"];)
    end.join("\n")}\n}"
  end
end
