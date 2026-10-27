# frozen_string_literal: true

require "prism"

class Hashira::Smells::Forwards
  DELEGATORS = %i[def_delegator def_delegators def_instance_delegator def_instance_delegators].freeze

  HANDS = %i[delegate].freeze

  def initialize(nodes, bonds, stock)
    @nodes = nodes
    @bonds = bonds
    @stock = stock
  end

  def to_h = pairs.filter_map { |name, target| [name, field(target)] if named?(target) }.to_h

  def names = pairs.to_set { |name, _| name.to_sym }

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
    target = symbol(Hashira::Analysis::Syntax.new(call).option("to"))
    Hashira::Smells::Attributes.new([call]).declared(HANDS).map { ["#{prefix(call, target)}#{it}", target] }
  end

  def prefix(call, target)
    given = Hashira::Analysis::Syntax.new(call).option("prefix")
    return "#{target}_" if given.is_a?(Prism::TrueNode)
    Hashira::Analysis::Syntax.new(given).word? ? "#{symbol(given)}_" : ""
  end

  def named?(target) = !target.empty? && !@stock.include?(target)

  def macros(kinds) = Hashira::Smells::Attributes.new(@nodes).macros(kinds)

  def field(target) = target.start_with?("@") ? target : @bonds.field(target)

  def symbol(node) = Hashira::Analysis::Syntax.new(node).literal.to_s.to_sym
end
