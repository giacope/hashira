# frozen_string_literal: true

require "prism"

module Hashira::Smells::Refusal
  RAISES = %i[raise fail].freeze

  module_function

  def of(definition)
    statements = Hashira::Analysis::Syntax.statements(definition).compact
    return :nothing if statements.all?(Prism::NilNode)
    :raise if statements.one? && raise?(statements.first)
  end

  def raise?(node) = node.is_a?(Prism::CallNode) && RAISES.include?(node.name) && !node.receiver

  def unimplemented?(definition) = of(definition) == :raise && definition.body.slice.include?("NotImplementedError")
end
