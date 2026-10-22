# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Words
  PATTERN = /\A[a-z][a-z_]*\z/

  Literal = Data.define(:words, :line)

  def initialize(tree)
    @tree = tree
  end

  def lists
    Hashira::Analysis::NodeWalk.new(@tree).collect.filter_map do |node|
      words = entries(node).compact.grep(PATTERN).to_set
      Literal.new(words:, line: node.location.start_line) unless words.empty?
    end
  end

  private

  def entries(node)
    case node
    when Prism::ArrayNode then node.elements.map { word(it) }
    when Prism::HashNode then keys(node)
    else []
    end
  end

  def keys(node) = node.elements.grep(Prism::AssocNode).map { word(it.key) }

  def word(node)
    case node
    when Prism::SymbolNode, Prism::StringNode then Hashira::Analysis::Syntax.new(node).text
    end
  end
end
