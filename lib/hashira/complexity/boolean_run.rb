# frozen_string_literal: true

class Hashira::Complexity::BooleanRun
  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node)
    @scorer.add(node, 1, "boolean")
    operands(node).each { @scorer.visit(it) }
  end

  private

  def operands(node)
    node.compact_child_nodes.flat_map do |child|
      inner = bare(child)
      inner.instance_of?(node.class) ? operands(inner) : [child]
    end
  end

  def bare(node)
    body = node.body if node.is_a?(Prism::ParenthesesNode)
    lone = body.body if body.is_a?(Prism::StatementsNode)
    lone&.one? ? bare(lone.first) : node
  end
end
