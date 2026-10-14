# frozen_string_literal: true

require "prism"

class Hashira::Smells::Sampling
  OPERATORS = %i[- + < > <= >= <=>].freeze

  def initialize(definition, calls)
    @definition = definition
    @calls = calls
  end

  def sampled?(nodes)
    kept = nodes.flat_map { |node| keepers(node) }
    kept.any? && nodes.any? { |node| measured?(node, kept) }
  end

  private

  def writes = @_writes ||= Hashira::Smells::Scope.inside(@definition).grep(Prism::LocalVariableWriteNode)

  def keepers(node) = writes.select { |write| holds?(write.value, node) }.map(&:name)

  def holds?(value, node) = value.equal?(node) || Hashira::Smells::Scope.inside(value).any? { it.equal?(node) }

  def measured?(node, kept) = @calls.any? { |call| against?(call, node, kept) }

  def against?(call, node, kept)
    return false unless OPERATORS.include?(call.name)
    operands = [call.receiver, *call.arguments.arguments]
    operands.any? { it.equal?(node) } && operands.any? { read?(it, kept) }
  end

  def read?(operand, kept) = operand.is_a?(Prism::LocalVariableReadNode) && kept.include?(operand.name)
end
