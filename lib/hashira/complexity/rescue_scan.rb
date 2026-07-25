# frozen_string_literal: true

module Hashira
  module Complexity
    class RescueScan
      def initialize(scorer)
        @scorer = scorer
      end

      def apply(node, nesting)
        @scorer.visit(node.statements, nesting)
        clauses(node.rescue_clause, nesting)
        @scorer.visit(node.else_clause, nesting)
        @scorer.visit(node.ensure_clause, nesting)
      end

      private

      def clauses(node, nesting)
        return unless node

        @scorer.add(node, 1 + nesting, "rescue")
        @scorer.visit(node.statements, nesting + 1)
        clauses(node.subsequent, nesting)
      end
    end
  end
end
