# frozen_string_literal: true

require "prism"

class Hashira::Analysis::Syntax::Word
  def initialize(node)
    @node = node
  end

  def to_s = @node.unescaped.scrub

  def to_a = word? ? [symbol] : []

  def symbol = to_s.to_sym

  def word? = @node.is_a?(Prism::StringNode) || @node.is_a?(Prism::SymbolNode)

  def named?(key) = @node.is_a?(Prism::SymbolNode) && to_s == key.to_s
end
