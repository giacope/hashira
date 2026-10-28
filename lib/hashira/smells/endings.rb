# frozen_string_literal: true

require "prism"
require_relative "bindings"
require_relative "scope"

class Hashira::Smells::Endings
  LOOPS = Hashira::Smells::Bindings::LOOPS

  JUMPS = [Prism::NextNode, Prism::BreakNode].freeze

  def initialize(definition)
    @definition = definition
  end

  def parts?(first, last)
    return false if sorted.fetch(Prism::EnsureNode, []).any? { covers?(it, last) }
    exits.any? { held?(it, first) && !held?(it, last) && within?(jumped(it), last) && !looped?(it, first, last) }
  end

  private

  def exits
    return @_exits if @_exits
    stops = nodes.select { exit?(it) } + sorted.fetch(Prism::AndNode, []).select { exit?(it.right) }
    @_exits = stops.reject { rescued?(it) }
  end

  def rescued?(exit) = raise?(jumped(exit)) && nodes.any? { rescue?(it) && covers?(it, exit) }

  def rescue?(node) = node.is_a?(Prism::RescueModifierNode) || (node.is_a?(Prism::BeginNode) && node.rescue_clause)

  def held?(exit, node) = covers?(exit, node) || preceding.fetch(exit, []).any? { covers?(it, node) }

  def within?(jump, node) = !JUMPS.include?(jump.class) || loops.none? { covers?(it, jump) && !covers?(it, node) }

  def looped?(exit, first, last)
    @_bindings ||= Hashira::Smells::Bindings.new(@definition)
    passes = @_bindings.free(first).flat_map { it.values_at(0, 2) }
    loops.any? { covers?(it, exit) && covers?(it, last) && !passes.include?(it.location.start_offset) }
  end

  def preceding
    @_preceding ||= sorted.fetch(Prism::StatementsNode, []).flat_map do |list|
      body = list.body
      body.each_with_index.filter_map { |statement, index| [statement, body.first(index)] if exit?(statement) }
    end.to_h.compare_by_identity
  end

  def jumped(exit) = exit.is_a?(Prism::AndNode) ? exit.right : exit

  def exit?(node) = [Prism::ReturnNode, *JUMPS].include?(node.class) || raise?(node)

  def raise?(node) = Hashira::Smells::Exits.new(node).raise?

  def loops = @_loops ||= sorted.values_at(*LOOPS).compact.flatten

  def covers?(outer, node) = Hashira::Smells::Scope.new(outer).covers?(node)

  def nodes = @_nodes ||= Hashira::Smells::Scope.new(@definition).inside

  def sorted = @_sorted ||= nodes.group_by(&:class)
end
