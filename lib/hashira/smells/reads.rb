# frozen_string_literal: true

require "prism"

module Hashira::Smells::Reads
  module_function

  def local?(node, &) = node.is_a?(Prism::LocalVariableReadNode) && yield(node.name)

  def key(call) = call.arguments&.arguments&.first
end
