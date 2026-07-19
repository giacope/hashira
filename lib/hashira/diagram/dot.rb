# frozen_string_literal: true

module Hashira
  module Diagram
    class Dot
      def initialize(edges)
        @edges = edges
      end

      def source
        lines = @edges.map { |from, to, weight| %(  "#{from}" -> "#{to}" [label="#{weight}"];) }
        "digraph hashira {\n  rankdir=LR;\n#{lines.join("\n")}\n}"
      end
    end
  end
end
