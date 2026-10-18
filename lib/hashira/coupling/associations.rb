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

  def option(call, key) = Hashira::Analysis::Syntax.option(call, key)

  def given(call)
    named = option(call, "class_name")
    Hashira::Analysis::Syntax.text(named) if named.is_a?(Prism::StringNode)
  end

  def inferred(call)
    source = literal(option(call, "source"))
    base = source || literal(call.arguments.arguments.first)
    return unless base
    COLLECTIONS.include?(call.name) || source ? @inflection.classify(base) : @inflection.camelize(base)
  end

  def literal(node)
    Hashira::Analysis::Syntax.text(node) if node.is_a?(Prism::StringNode) || node.is_a?(Prism::SymbolNode)
  end
end

Hashira::Coupling::Associations::NONE = Hashira::Coupling::Associations.new(nil)
