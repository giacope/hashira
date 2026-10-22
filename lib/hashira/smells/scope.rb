# frozen_string_literal: true

require "prism"

class Hashira::Smells::Scope
  TYPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  FENCES = (TYPES + [Prism::DefNode]).freeze

  def initialize(node)
    @node = node
  end

  def inside = below(FENCES)

  def sweep = below(TYPES)

  def covers?(node) = stretch.cover?(Hashira::Smells::Scope.new(node).stretch)

  def stretch
    spot = @node.location
    spot.start_offset..spot.end_offset
  end

  def below(fences)
    found = []
    visit(@node, fences) { found << it }
    found
  end

  private

  def visit(root, fences, &)
    root.compact_child_nodes.each do |child|
      next if fences.include?(child.class)
      yield(child)
      visit(child, fences, &)
    end
  end
end
