# frozen_string_literal: true

require "prism"

class Hashira::Smells::Tuples
  VALUES = { "Struct" => :new, "Data" => :define, "::Struct" => :new, "::Data" => :define }.freeze

  def initialize(types)
    @types = types
  end

  def bags
    @types.flat_map do |type|
      Hashira::Analysis::Syntax.new(type.node).constants.filter_map { valued(type, it.name.to_s, it.value) } +
        [valued(type, nil, superclass(type))].compact
    end
  end

  private

  def superclass(type) = (type.node.superclass if type.node.is_a?(Prism::ClassNode) && type.defs.empty?)

  def valued(type, constant, value)
    return unless Hashira::Smells::Factory.new(value).made?(VALUES) && bare?(value.block)
    name = constant ? "#{type.name}::#{constant}" : type.name
    Hashira::Smells::Bags::Bag.new(name:, site: "#{type.file}:#{value.location.start_line}", fields: fields(value))
  end

  def bare?(block) = block.nil? || Hashira::Smells::Scope.new(block).sweep.none?(Prism::DefNode)

  def fields(value) = Array(value.arguments&.arguments).grep(Prism::SymbolNode).to_set { it.unescaped.to_sym }
end
