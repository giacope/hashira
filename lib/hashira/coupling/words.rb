# frozen_string_literal: true

require "prism"

module Hashira::Coupling::Words
  PATTERN = /\A[a-z][a-z_]*\z/

  module_function

  def list(tree)
    Hashira::Analysis::NodeWalk.collect(tree).flat_map { entries(it) }.compact.grep(PATTERN).to_set
  end

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
    when Prism::SymbolNode, Prism::StringNode then node.unescaped
    end
  end
end
