# frozen_string_literal: true

require "prism"

class Hashira::Smells::Raises
  def initialize(home, errands = Hashira::Smells::Errands.new(home))
    @errands = errands
  end

  def any?(nodes) = nodes.any? { ends?(it, Set[]) }

  private

  def ends?(node, seen) = Hashira::Smells::Exits.new(node).raise? || reached(node).any? { fails?(it, seen) }

  def fails?(definition, seen)
    seen.add?(definition.name) && Hashira::Smells::Scope.new(definition).inside.none?(Prism::ReturnNode) &&
      ends?(Hashira::Analysis::Syntax::Body.new(definition).to_a.last, seen)
  end

  def reached(node) = node.is_a?(Prism::CallNode) ? @errands.reached(node) : []
end
