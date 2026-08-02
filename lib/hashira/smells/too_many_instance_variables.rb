# frozen_string_literal: true

require "prism"

class Hashira::Smells::TooManyInstanceVariables < Hashira::Smells::Check
  LIMIT = 4

  COUNTED = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  private

  def smelly? = subject.kind == :class && names.size > LIMIT

  def names
    @names ||= Hashira::Smells::Scope.sweep(subject.node).select { COUNTED.include?(it.class) }.map(&:name).uniq.sort
  end

  def message
    "#{label} holds #{names.size} instance variables (#{site}). " \
      "Split the class, or gather related fields into value objects."
  end

  def evidence = names.map(&:to_s)
end
