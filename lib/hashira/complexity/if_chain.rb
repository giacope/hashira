# frozen_string_literal: true

require "prism"

class Hashira::Complexity::IfChain
  def initialize(walk)
    @walk = walk
  end

  def apply(node)
    return ternary(node) unless node.if_keyword
    branch(node, @walk.charge(node, "if")) + tail(node.subsequent)
  end

  def negated(node) = branch(node, @walk.charge(node, "unless")) + tail(node.else_clause)

  private

  def branch(node, marked) = marked + @walk.visit(node.predicate) + @walk.deeper.visit(node.statements)

  def tail(node)
    case node
    when Prism::IfNode then branch(node, Hashira::Complexity::Charges.mark(node, 1, "elsif")) + tail(node.subsequent)
    when Prism::ElseNode then Hashira::Complexity::Charges.mark(node, 1, "else") + @walk.deeper.visit(node.statements)
    else Hashira::Complexity::Charges.none
    end
  end

  def ternary(node)
    deeper = @walk.deeper
    branches = [node.statements, node.subsequent].sum(Hashira::Complexity::Charges.none) { deeper.visit(it) }
    @walk.charge(node, "ternary") + @walk.visit(node.predicate) + branches
  end
end
