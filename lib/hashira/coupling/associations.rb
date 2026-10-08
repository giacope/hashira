# frozen_string_literal: true

require "prism"

module Hashira::Coupling::Associations
  MACROS = %i[has_many has_one belongs_to has_and_belongs_to_many].freeze

  OPTION = "class_name"

  CONSTANT = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*\z/

  module_function

  def names(node) = macro?(node) ? options(node).select { named?(it) }.map(&:value) : []

  def macro?(node) = Hashira::Analysis::Syntax.macro?(node, MACROS)

  def options(call) = call.arguments.arguments.grep(Prism::KeywordHashNode).flat_map(&:elements).grep(Prism::AssocNode)

  def named?(option) = keyed?(option.key) && constant?(option.value)

  def keyed?(key) = key.is_a?(Prism::SymbolNode) && key.unescaped == OPTION

  def constant?(value) = value.is_a?(Prism::StringNode) && value.unescaped.match?(CONSTANT)
end
