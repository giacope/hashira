# frozen_string_literal: true

require "prism"

module Hashira::Smells::Conditions
  TESTED = [Prism::IfNode, Prism::UnlessNode, Prism::CaseNode, Prism::AndNode, Prism::OrNode].freeze

  LOOPS = [Prism::WhileNode, Prism::UntilNode].freeze

  module_function

  def tested?(node) = TESTED.include?(node.class)

  def steers?(node, parent) = tested?(node) && !(couple?(node) && carried?(node, parent))

  def carried?(node, parent)
    return !LOOPS.include?(parent.class) unless parent.is_a?(Prism::StatementsNode)
    node.is_a?(Prism::OrNode)
  end

  def fence?(node) = Hashira::Smells::Scope::FENCES.include?(node.class)

  def couple?(node) = node.is_a?(Prism::AndNode) || node.is_a?(Prism::OrNode)

  def condition(node)
    case node
    when Prism::IfNode, Prism::UnlessNode, Prism::CaseNode then node.predicate
    when Prism::AndNode, Prism::OrNode then node.left
    end
  end

  def branches(node)
    return fork(node) if node.is_a?(Prism::IfNode) || node.is_a?(Prism::UnlessNode)
    return node.conditions + [node.consequent] if node.is_a?(Prism::CaseNode)
    couple?(node) ? [node.right] : [node.body]
  end

  def fork(node)
    [node.statements, node.is_a?(Prism::IfNode) ? node.subsequent : node.else_clause]
  end

  def nested(roots) = roots.compact.flat_map { seek(it) }

  def seek(node, parent = nil)
    return [node] if steers?(node, parent)
    fence?(node) ? [] : node.compact_child_nodes.flat_map { seek(it, node) }
  end

  def plain(node, parent = nil)
    return [] if steers?(node, parent) || fence?(node)
    [node] + node.compact_child_nodes.flat_map { plain(it, node) }
  end
end
