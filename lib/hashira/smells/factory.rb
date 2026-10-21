# frozen_string_literal: true

require "prism"

module Hashira::Smells::Factory
  module_function

  def made?(value, table) = value.is_a?(Prism::CallNode) && table[value.receiver&.slice] == value.name

  def constant?(node) = node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)
end
