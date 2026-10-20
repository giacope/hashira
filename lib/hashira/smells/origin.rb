# frozen_string_literal: true

require "prism"

module Hashira::Smells::Origin
  SELVES = [NilClass, Prism::SelfNode].freeze

  module_function

  def of(node, singleton)
    return node.name.to_s if node.is_a?(Prism::InstanceVariableReadNode)
    "#{singleton ? "." : "#"}#{node.name}" if own?(node)
  end

  def own?(node) = node.is_a?(Prism::CallNode) && !node.arguments && SELVES.include?(node.receiver.class)
end
