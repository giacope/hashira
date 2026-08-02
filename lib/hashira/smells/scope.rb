# frozen_string_literal: true

require "prism"

module Hashira::Smells::Scope
  TYPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  FENCES = (TYPES + [Prism::DefNode]).freeze

  module_function

  def inside(node) = below(node, FENCES)

  def sweep(node) = below(node, TYPES)

  def below(root, fences)
    found = []
    visit(root, fences) { found << it }
    found
  end

  def visit(root, fences, &)
    root.compact_child_nodes.each do |child|
      next if fences.include?(child.class)
      yield(child)
      visit(child, fences, &)
    end
  end
end
