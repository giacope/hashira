# frozen_string_literal: true

require "prism"

module Hashira::Smells::Mapping
  FIXED = [
    Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::FloatNode, Prism::NilNode, Prism::TrueNode,
    Prism::FalseNode, Prism::RegularExpressionNode, Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  TRANSLATIONS = %i[t translate].freeze

  module_function

  def literal?(branch)
    found = outcome(branch)
    found.one? && value?(found.first)
  end

  def outcome(branch)
    case branch
    when Prism::StatementsNode then branch.body
    when Prism::ElseNode, Prism::WhenNode then Array(branch.statements&.body)
    else [branch]
    end
  end

  def value?(node) = FIXED.include?(node.class) || translated?(node)

  def translated?(node)
    node.is_a?(Prism::CallNode) && TRANSLATIONS.include?(node.name) && keyed?(node)
  end

  def keyed?(call) = Hashira::Smells::Foreign::KEYS.include?(Array(call.arguments&.arguments).first.class)
end
