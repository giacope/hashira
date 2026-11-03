# frozen_string_literal: true

require "prism"

class Hashira::Smells::News
  FENCES = [Prism::ClassNode, Prism::ModuleNode].freeze

  private_constant :FENCES

  def initialize(type)
    @node = type
  end

  def each(&) = made(@node, nil).each(&)

  private

  def made(node, factory)
    node.compact_child_nodes.reject { FENCES.include?(it.class) }.flat_map do |child|
      built = child.is_a?(Prism::CallNode) && child.name == :new ? [[child, factory]] : []
      built + made(child, child.is_a?(Prism::DefNode) ? child.name : factory)
    end
  end
end
