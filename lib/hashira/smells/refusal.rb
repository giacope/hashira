# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refusal
  RAISES = %i[raise fail].freeze

  UNIMPLEMENTED = /\b(?:NotImplementedError|NoMethodError)\b/

  def initialize(definition)
    @definition = definition
  end

  def of
    statements = Hashira::Analysis::Syntax::Body.new(@definition).to_a.compact
    return [:nothing] if statements.all?(Prism::NilNode)
    statements.one? && raise?(statements.first) ? [:raise] : []
  end

  def unimplemented? = of == [:raise] && UNIMPLEMENTED.match?(@definition.body.slice)

  private

  def raise?(node) = node.is_a?(Prism::CallNode) && RAISES.include?(node.name) && !node.receiver
end
