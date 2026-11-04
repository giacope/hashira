# frozen_string_literal: true

require "prism"

class Hashira::Smells::Forwards
  DELEGATORS = %i[def_delegator def_delegators def_instance_delegator def_instance_delegators].freeze

  HANDS = %i[delegate].freeze

  def initialize(nodes, bonds = Hashira::Smells::Bonds.new(nodes), stock = Set.new)
    @nodes = nodes
    @bonds = bonds
    @stock = stock
  end

  def to_h = pairs.filter_map { |name, target| [name, field(target)] if named?(target) }.to_h

  def names = pairs.to_set { |name, _| name.to_sym }

  def field(target) = target.start_with?("@") ? target : @bonds.field(target)

  private

  def pairs = @_pairs ||= forwarded + handed

  def forwarded
    macros(DELEGATORS).flat_map do |call|
      target, *names = Array(call.arguments&.arguments).map { symbol(it) }
      names.reject(&:empty?).map { [it.to_s, target] }
    end
  end

  def handed = macros(HANDS).flat_map { handing(it) }

  def handing(call)
    target = symbol(Hashira::Analysis::Syntax::Value.new(call).given("to").first)
    Hashira::Smells::Attributes.new([call]).declared(HANDS).map { ["#{prefix(call, target)}#{it}", target] }
  end

  def prefix(call, target)
    given = Hashira::Analysis::Syntax::Value.new(call).given("prefix")
    return "#{target}_" if given.any?(Prism::TrueNode)
    given.select { Hashira::Analysis::Syntax::Word.new(it).word? }.map { "#{symbol(it)}_" }.join
  end

  def named?(target) = !target.empty? && !@stock.include?(target)

  def macros(kinds) = Hashira::Smells::Attributes.new(@nodes).macros(kinds)

  def symbol(node) = Hashira::Analysis::Syntax::Word.new(node).to_a.first.to_s.to_sym
end
