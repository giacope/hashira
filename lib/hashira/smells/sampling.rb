# frozen_string_literal: true

require "prism"

class Hashira::Smells::Sampling
  OPERATORS = %i[- + < > <= >= <=>].freeze

  def initialize(definition, calls)
    @definition = definition
    @calls = calls
  end

  def sampled?(nodes) = measured?(nodes) || nodes.all? { |node| holds?(node) }

  private

  def measured?(nodes)
    kept = nodes.flat_map { |node| keepers(node) }
    kept.any? && nodes.any? { |node| compared?(node, kept) }
  end

  def holds?(node) = Hashira::Smells::Scope.new(node).inside.grep(Prism::CallNode).any? { measured?(readings(it)) }

  def readings(node) = @calls.select { it.slice == node.slice }

  def writes = @_writes ||= Hashira::Smells::Scope.new(@definition).inside.grep(Prism::LocalVariableWriteNode)

  def keepers(node) = writes.select { |write| keeps?(write.value, node) }.map(&:name)

  def keeps?(value, node) = value.equal?(node) || Hashira::Smells::Scope.new(value).inside.any? { it.equal?(node) }

  def compared?(node, kept) = @calls.any? { |call| against?(call, node, kept) }

  def against?(call, node, kept)
    return false unless OPERATORS.include?(call.name)
    operands = [call.receiver, *call.arguments.arguments]
    operands.any? { bare(it).equal?(node) } && operands.any? { read?(it, kept) }
  end

  def bare(operand)
    case operand
    when Prism::ParenthesesNode then bare(Hashira::Analysis::Syntax.new(operand).statements.last)
    when Prism::LocalVariableWriteNode then bare(operand.value)
    else operand
    end
  end

  def read?(operand, kept) = operand.is_a?(Prism::LocalVariableReadNode) && kept.include?(operand.name)
end
