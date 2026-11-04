# frozen_string_literal: true

require "prism"

class Hashira::Smells::Scope
  TYPES = [Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze

  FENCES = (TYPES + [Prism::DefNode]).freeze

  CLOSURES = [Prism::BlockNode, Prism::LambdaNode].freeze

  private_constant :TYPES, :FENCES, :CLOSURES

  def initialize(node)
    @node = node
  end

  def inside(*fences) = below(FENCES + fences)

  def sweep = below(TYPES)

  def bare = below(FENCES + CLOSURES)

  private

  def below(fences)
    found = []
    visit(@node, fences) { found << it }
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
