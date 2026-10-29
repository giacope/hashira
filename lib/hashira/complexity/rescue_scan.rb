# frozen_string_literal: true

class Hashira::Complexity::RescueScan
  def initialize(walk)
    @walk = walk
  end

  def apply(node)
    @walk.visit(node.statements) + clauses(node.rescue_clause) + @walk.visit(node.else_clause) +
      @walk.visit(node.ensure_clause)
  end

  def modifier(node) = @walk.visit(node.expression) + handler(node, node.rescue_expression)

  private

  def handler(node, recovery) = @walk.charge(node, "rescue") + @walk.deeper.visit(recovery)

  def clauses(node)
    node ? handler(node, node.statements) + clauses(node.subsequent) : Hashira::Complexity::Charges.none
  end
end
