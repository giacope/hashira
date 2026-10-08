# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Literal
  VALUES = [
    Prism::ArrayNode, Prism::AssocNode, Prism::FalseNode, Prism::FloatNode,
    Prism::HashNode, Prism::IntegerNode, Prism::InterpolatedStringNode, Prism::KeywordHashNode,
    Prism::NilNode, Prism::RegularExpressionNode, Prism::StringNode, Prism::SymbolNode, Prism::TrueNode
  ].freeze
  NAMES = [Prism::ConstantReadNode, Prism::ConstantPathNode].freeze

  def initialize(node, pardoned = [])
    @node = node
    @pardoned = pardoned
  end

  def literal? = VALUES.include?(type) && parts.all?(&:literal?)

  def literals? = parts.all?(&:declarative?)

  def declarative? = @pardoned.include?(@node) || ((VALUES + NAMES).include?(type) && literals?)

  private

  def type = @node.class

  def parts = children.map { Hashira::Duplication::Literal.new(it, @pardoned) }

  def children = Array(@node&.compact_child_nodes)
end
