# frozen_string_literal: true

require "prism"

class Hashira::Complexity::IfChain
  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node)
    return ternary(node) unless node.if_keyword
    branch(node, 1 + @scorer.nesting, "if")
  end

  private

  def branch(node, cost, label)
    @scorer.add(node, cost, label)
    @scorer.visit(node.predicate)
    @scorer.deeper { @scorer.visit(node.statements) }
    tail(node.subsequent)
  end

  def tail(node)
    case node
    when Prism::IfNode then branch(node, 1, "elsif")
    when Prism::ElseNode then otherwise(node)
    end
  end

  def otherwise(node)
    @scorer.add(node, 1, "else")
    @scorer.deeper { @scorer.visit(node.statements) }
  end

  def ternary(node)
    @scorer.add(node, 1, "ternary")
    node.compact_child_nodes.each { @scorer.visit(it) }
  end
end
