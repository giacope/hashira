# frozen_string_literal: true

require "prism"

class Hashira::Smells::Factory
  def initialize(node)
    @node = node
  end

  def made?(table) = @node.is_a?(Prism::CallNode) && table[@node.receiver&.slice] == @node.name

  def constant? = @node.is_a?(Prism::ConstantReadNode) || @node.is_a?(Prism::ConstantPathNode)
end
