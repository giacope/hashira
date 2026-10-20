# frozen_string_literal: true

require "prism"

class Hashira::Complexity::BooleanRun
  CONNECTIVES = [Prism::AndNode, Prism::OrNode].freeze

  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node)
    operators = []
    leaves = []
    walk(node, operators, leaves)
    @scorer.add(node, operators.chunk_while { |left, right| left == right }.count, "boolean")
    leaves.each { @scorer.visit(it) }
  end

  private

  def walk(node, operators, leaves)
    inner = bare(node)
    return leaves << node unless CONNECTIVES.include?(inner.class)
    walk(inner.left, operators, leaves)
    operators << inner.class
    walk(inner.right, operators, leaves)
  end

  def bare(node)
    body = node.body if node.is_a?(Prism::ParenthesesNode)
    lone = body.body if body.is_a?(Prism::StatementsNode)
    lone&.one? ? bare(lone.first) : node
  end
end
