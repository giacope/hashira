# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refusal
  RAISES = %i[raise fail].freeze

  UNIMPLEMENTED = /\b(?:NotImplementedError|NoMethodError)\b/

  def initialize(definition)
    @definition = definition
  end

  def of
    statements = Hashira::Analysis::Syntax.new(@definition).statements.compact
    return :nothing if statements.all?(Prism::NilNode)
    :raise if statements.one? && raise?(statements.first)
  end

  def unimplemented? = of == :raise && UNIMPLEMENTED.match?(@definition.body.slice)

  private

  def raise?(node) = node.is_a?(Prism::CallNode) && RAISES.include?(node.name) && !node.receiver
end
