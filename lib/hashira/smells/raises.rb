# frozen_string_literal: true

require "prism"

class Hashira::Smells::Raises
  def initialize(home)
    @home = home
  end

  def raise?(node) = ends?(node, Set[])

  private

  def ends?(node, seen) = Hashira::Smells::Exits.new(node).raise? || reached(node).any? { fails?(it, seen) }

  def fails?(definition, seen)
    seen.add?(definition.name) && Hashira::Smells::Scope.new(definition).inside.none?(Prism::ReturnNode) &&
      ends?(Hashira::Analysis::Syntax.new(definition).statements.last, seen)
  end

  def reached(node) = node.is_a?(Prism::CallNode) ? errands.reached(node) : []

  def errands = @_errands ||= Hashira::Smells::Errands.new(@home)
end
