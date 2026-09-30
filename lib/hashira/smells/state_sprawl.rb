# frozen_string_literal: true

require "prism"

class Hashira::Smells::StateSprawl < Hashira::Smells::Check
  LIMIT = 4

  COUNTED = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  private

  def smelly? = subject.kind == :class && names.size > LIMIT

  def names
    @_names ||= writes.map(&:name).uniq.reject { it.start_with?("@_") || memoized?(it) }.sort
  end

  def nodes = @_nodes ||= Hashira::Smells::Scope.sweep(subject.node)

  def writes = @_writes ||= nodes.select { COUNTED.include?(it.class) }

  def memoized?(name) = probed.include?(name) || (cached.include?(name) && cleared?(name))

  def cleared?(name) = writes.select { it.name == name }.all? { blank?(it) }

  def blank?(write) = write.is_a?(Prism::InstanceVariableWriteNode) && write.value.is_a?(Prism::NilNode)

  def cached = @_cached ||= nodes.grep(Prism::InstanceVariableOrWriteNode).map(&:name)

  def probed
    @_probed ||= nodes.grep(Prism::DefinedNode).map(&:value).grep(Prism::InstanceVariableReadNode).map(&:name)
  end

  def detail = { site:, count: names.size }

  def evidence = names.map(&:to_s)
end
