# frozen_string_literal: true

require "prism"

class Hashira::Smells::Conditions
  def initialize(node)
    @node = node
  end

  def couple? = @node.is_a?(Prism::AndNode) || @node.is_a?(Prism::OrNode)

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

  private

  def fork = [@node.statements, @node.is_a?(Prism::IfNode) ? @node.subsequent : @node.else_clause]
end
