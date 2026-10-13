# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Associations
  MACROS = %i[has_many has_one belongs_to has_and_belongs_to_many].freeze

  COLLECTIONS = %i[has_many has_and_belongs_to_many].freeze

  CONSTANT = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*\z/

  Target = Data.define(:name, :line)

  def initialize(inflection)
    @inflection = inflection
  end

  def targets(node)
    return [] unless Hashira::Analysis::Syntax.macro?(node, MACROS) && !option(node, "polymorphic").is_a?(Prism::TrueNode)
    name = given(node) || inferred(node)
    name&.match?(CONSTANT) ? [Target.new(name:, line: node.location.start_line)] : []
  end

  private

  def options(call) = call.arguments.arguments.grep(Prism::KeywordHashNode).flat_map(&:elements).grep(Prism::AssocNode)

  def option(call, key) = options(call).find { keyed?(it.key, key) }&.value

  def keyed?(node, key) = node.is_a?(Prism::SymbolNode) && node.unescaped == key

  def given(call)
    named = option(call, "class_name")
    named.unescaped if named.is_a?(Prism::StringNode)
  end

  def inferred(call)
    source = literal(option(call, "source"))
    base = source || literal(call.arguments.arguments.first)
    return unless base
    COLLECTIONS.include?(call.name) || source ? @inflection.classify(base) : @inflection.camelize(base)
  end

  def literal(node) = (node.unescaped if node.is_a?(Prism::StringNode) || node.is_a?(Prism::SymbolNode))
end

Hashira::Coupling::Associations::NONE = Hashira::Coupling::Associations.new(nil)
