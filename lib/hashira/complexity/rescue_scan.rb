# frozen_string_literal: true

class Hashira::Complexity::RescueScan
  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node)
    @scorer.visit(node.statements)
    clauses(node.rescue_clause)
    @scorer.visit(node.else_clause)
    @scorer.visit(node.ensure_clause)
  end

  private

  def clauses(node)
    return unless node
    @scorer.add(node, 1 + @scorer.nesting, "rescue")
    @scorer.deeper { @scorer.visit(node.statements) }
    clauses(node.subsequent)
  end
end
