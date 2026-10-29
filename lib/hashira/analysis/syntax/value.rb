# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax::Value
  FIXED = [
    Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::FloatNode, Prism::NilNode, Prism::TrueNode,
    Prism::FalseNode, Prism::RegularExpressionNode, Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  DEFAULTS = (FIXED - [Prism::NilNode] + [Prism::ArrayNode, Prism::HashNode]).freeze

  private_constant :FIXED, :DEFAULTS

  def initialize(node)
    @node = node
  end

  def fixed? = FIXED.include?(@node.class)

  def default? = DEFAULTS.include?(@node.class)

  def thaw = @node.is_a?(Prism::CallNode) && @node.name == :freeze ? @node.receiver : @node

  def to_a = keywords.flat_map(&:elements).grep(Prism::AssocNode)

  def given(key) = to_a.select { Hashira::Analysis::Syntax::Word.new(it.key).named?(key) }.first(1).map(&:value)

  private

  def keywords = Array(@node.arguments&.arguments).grep(Prism::KeywordHashNode)
end
