# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Literal
  TYPES = [
    Prism::ArrayNode, Prism::AssocNode, Prism::FalseNode, Prism::FloatNode,
    Prism::HashNode, Prism::IntegerNode, Prism::KeywordHashNode, Prism::NilNode,
    Prism::StringNode, Prism::SymbolNode, Prism::TrueNode
  ].freeze

  def initialize(node)
    @node = node
  end

  def literal? = TYPES.include?(@node.class) && parts.all?(&:literal?)

  def literals? = parts.all?(&:literal?)

  private

  def parts = children.map { Hashira::Duplication::Literal.new(it) }

  def children = Array(@node&.compact_child_nodes)
end
