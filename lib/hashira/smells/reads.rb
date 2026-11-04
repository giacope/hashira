# frozen_string_literal: true

require "prism"

module Hashira::Smells::Reads
  private

  def local?(node, &) = node.is_a?(Prism::LocalVariableReadNode) && yield(node.name)

  def keys(call) = Array(call.arguments&.arguments).first(1)
end
