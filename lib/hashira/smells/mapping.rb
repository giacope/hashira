# frozen_string_literal: true

require "prism"

class Hashira::Smells::Mapping
  FIXED = [
    Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::FloatNode, Prism::NilNode, Prism::TrueNode,
    Prism::FalseNode, Prism::RegularExpressionNode, Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  TRANSLATIONS = %i[t translate].freeze

  def initialize(node)
    @node = node
  end

  def literal?
    found = outcome
    found.one? && value?(found.first)
  end

  def built?
    found = outcome
    found.one? && Hashira::Smells::Mapping.new(found.first).made?
  end

  def made?
    @node.is_a?(Prism::CallNode) && @node.name == :new && Hashira::Smells::Factory.new(@node.receiver).constant?
  end

  private

  def outcome
    case @node
    when Prism::StatementsNode then @node.body
    when Prism::ElseNode, Prism::WhenNode then Array(@node.statements&.body)
    else [@node]
    end
  end

  def value?(node) = FIXED.include?(node.class) || translated?(node)

  def translated?(node) = node.is_a?(Prism::CallNode) && TRANSLATIONS.include?(node.name) && keyed?(node)

  def keyed?(call) = Hashira::Smells::Foreign::KEYS.include?(Array(call.arguments&.arguments).first.class)
end
