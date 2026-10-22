# frozen_string_literal: true

require "prism"

class Hashira::Smells::Conditions
  TESTED = [Prism::IfNode, Prism::UnlessNode, Prism::CaseNode, Prism::AndNode, Prism::OrNode].freeze

  LOOPS = [Prism::WhileNode, Prism::UntilNode].freeze

  def initialize(node)
    @node = node
  end

  def couple? = couples?(@node)

  def condition
    case @node
    when Prism::IfNode, Prism::UnlessNode, Prism::CaseNode then @node.predicate
    when Prism::AndNode, Prism::OrNode then @node.left
    end
  end

  def branches
    return fork if @node.is_a?(Prism::IfNode) || @node.is_a?(Prism::UnlessNode)
    return @node.conditions + [@node.consequent] if @node.is_a?(Prism::CaseNode)
    couple? ? [@node.right] : [@node.body]
  end

  def nested = @node.compact.flat_map { tested?(it) ? [it] : seek(it) }

  def plain = tested?(@node) ? [] : spread(@node)

  private

  def tested?(node) = TESTED.include?(node.class)

  def steers?(node, parent) = tested?(node) && !(couples?(node) && carried?(node, parent))

  def carried?(node, parent)
    return !LOOPS.include?(parent.class) unless parent.is_a?(Prism::StatementsNode)
    node.is_a?(Prism::OrNode)
  end

  def fence?(node) = Hashira::Smells::Scope::FENCES.include?(node.class)

  def couples?(node) = node.is_a?(Prism::AndNode) || node.is_a?(Prism::OrNode)

  def fork = [@node.statements, @node.is_a?(Prism::IfNode) ? @node.subsequent : @node.else_clause]

  def seek(node)
    return [] if fence?(node)
    node.compact_child_nodes.flat_map { steers?(it, node) ? [it] : seek(it) }
  end

  def spread(node)
    return [] if fence?(node)
    [node] + node.compact_child_nodes.reject { steers?(it, node) }.flat_map { spread(it) }
  end
end
