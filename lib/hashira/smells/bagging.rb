# frozen_string_literal: true

require "prism"

class Hashira::Smells::Bagging
  VALUES = { "Struct" => :new, "Data" => :define, "::Struct" => :new, "::Data" => :define }.freeze

  private_constant :VALUES

  def initialize(type, name, seat, lone)
    @node = type
    @name = name
    @seat = seat
    @lone = lone
  end

  def to_a
    Hashira::Analysis::Syntax::Body.new(@node).constants.filter_map { valued(it.name.to_s, it.value) } +
      [valued(nil, superclass)].compact
  end

  private

  def superclass = (@node.superclass if @node.is_a?(Prism::ClassNode) && @lone)

  def valued(constant, value)
    return unless Hashira::Smells::Factory.new(value).made?(VALUES) && bare?(value.block)
    name = constant ? "#{@name}::#{constant}" : @name
    Hashira::Smells::Bags::Bag.new(name:, site: @seat.at(value.location.start_line), fields: fields(value))
  end

  def bare?(block) = block.nil? || Hashira::Smells::Scope.new(block).sweep.none?(Prism::DefNode)

  def fields(value) = Array(value.arguments&.arguments).grep(Prism::SymbolNode).to_set { it.unescaped.to_sym }
end
