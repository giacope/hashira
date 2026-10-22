# frozen_string_literal: true

require "prism"

class Hashira::Complexity::BooleanRun
  CONNECTIVES = [Prism::AndNode, Prism::OrNode].freeze

  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node)
    operators, leaves = walk(node)
    @scorer.add(node, operators.chunk_while { |left, right| left == right }.count, "boolean")
    leaves.each { @scorer.visit(it) }
  end

  private

  def walk(node)
    inner = bare(node)
    return [[], [node]] unless CONNECTIVES.include?(inner.class)
    left_operators, left_leaves = walk(inner.left)
    right_operators, right_leaves = walk(inner.right)
    [left_operators + [inner.class] + right_operators, left_leaves + right_leaves]
  end

  def bare(node)
    body = node.body if node.is_a?(Prism::ParenthesesNode)
    lone = body.body if body.is_a?(Prism::StatementsNode)
    lone&.one? ? bare(lone.first) : node
  end
end
