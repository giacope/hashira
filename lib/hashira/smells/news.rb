# frozen_string_literal: true

require "prism"

class Hashira::Smells::News
  FENCES = [Prism::ClassNode, Prism::ModuleNode].freeze

  private_constant :FENCES

  def initialize(type)
    @node = type
  end

  def each(&) = made(@node, nil, &)

  private

  def made(node, factory, &)
    node.compact_child_nodes.each do |child|
      next if FENCES.include?(child.class)
      yield([child, factory]) if child.is_a?(Prism::CallNode) && child.name == :new
      made(child, child.is_a?(Prism::DefNode) ? child.name : factory, &)
    end
  end
end
