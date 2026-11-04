# frozen_string_literal: true

require "prism"

class Hashira::Smells::Conditionals
  TESTED = [Prism::IfNode, Prism::UnlessNode, Prism::CaseNode, Prism::AndNode, Prism::OrNode].freeze

  LOOPS = [Prism::WhileNode, Prism::UntilNode].freeze

  private_constant :TESTED, :LOOPS

  def initialize(nodes)
    @nodes = nodes
  end

  def nested = @nodes.compact.flat_map { tested?(it) ? [it] : seek(it) }

  def plain = @nodes.flat_map { tested?(it) ? [] : spread(it) }

  private

  def tested?(node) = TESTED.include?(node.class)

  def steers?(node, parent) = tested?(node) && !(couple?(node) && carried?(node, parent))

  def couple?(node) = Hashira::Smells::Conditions.new(node).couple?

  def carried?(node, parent)
    return !LOOPS.include?(parent.class) unless parent.is_a?(Prism::StatementsNode)
    node.is_a?(Prism::OrNode)
  end

  def fence?(node) = Hashira::Smells::Border.new(node).fence?

  def seek(node)
    return [] if fence?(node)
    node.compact_child_nodes.flat_map { steers?(it, node) ? [it] : seek(it) }
  end

  def spread(node)
    return [] if fence?(node)
    [node] + node.compact_child_nodes.reject { steers?(it, node) }.flat_map { spread(it) }
  end
end
