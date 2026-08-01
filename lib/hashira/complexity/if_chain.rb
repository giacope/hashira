# frozen_string_literal: true

require "prism"

class Hashira::Complexity::IfChain
  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node, nesting)
    return ternary(node, nesting) unless node.if_keyword
    branch(node, 1 + nesting, nesting, "if")
  end

  private

  def branch(node, cost, nesting, label)
    @scorer.add(node, cost, label)
    @scorer.visit(node.predicate, nesting)
    @scorer.visit(node.statements, nesting + 1)
    tail(node.subsequent, nesting)
  end

  def tail(node, nesting)
    case node
    when Prism::IfNode then branch(node, 1, nesting, "elsif")
    when Prism::ElseNode then otherwise(node, nesting)
    end
  end

  def otherwise(node, nesting)
    @scorer.add(node, 1, "else")
    @scorer.visit(node.statements, nesting + 1)
  end

  def ternary(node, nesting)
    @scorer.add(node, 1, "ternary")
    node.compact_child_nodes.each { @scorer.visit(it, nesting) }
  end
end
