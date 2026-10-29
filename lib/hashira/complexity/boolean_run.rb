# frozen_string_literal: true

require "prism"

class Hashira::Complexity::BooleanRun
  CONNECTIVES = [Prism::AndNode, Prism::OrNode].freeze

  def initialize(walk)
    @walk = walk
  end

  def apply(node)
    operators, leaves = joined(node)
    runs = operators.chunk_while { |left, right| left == right }.count
    Hashira::Complexity::Charges.mark(node, runs, "boolean") + leaves.sum(Hashira::Complexity::Charges.none) { @walk.visit(it) }
  end

  private

  def joined(node)
    inner = bare(node)
    return [[], [node]] unless CONNECTIVES.include?(inner.class)
    left_operators, left_leaves = joined(inner.left)
    right_operators, right_leaves = joined(inner.right)
    [left_operators + [inner.class] + right_operators, left_leaves + right_leaves]
  end

  def bare(node)
    body = node.body if node.is_a?(Prism::ParenthesesNode)
    lone = body.body if body.is_a?(Prism::StatementsNode)
    lone&.one? ? bare(lone.first) : node
  end
end
