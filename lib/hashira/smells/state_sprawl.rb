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

  def memoized?(name) = lazy?(name) && writes.select { it.name == name }.all? { blank?(it) || guarded?(it) }

  def lazy?(name) = cached.include?(name) || probed.include?(name)

  def probed = @_probed ||= probes(nodes)

  def blank?(write) = write.is_a?(Prism::InstanceVariableWriteNode) && write.value.is_a?(Prism::NilNode)

  def guarded?(write) = guarded.any? { it.equal?(write) }

  def guarded = @_guarded ||= nodes.grep(Prism::DefNode).flat_map { shielded(Hashira::Smells::Scope.sweep(it)) }

  def shielded(body)
    probed = probes(body)
    body.select { COUNTED.include?(it.class) && probed.include?(it.name) }
  end

  def cached = @_cached ||= nodes.grep(Prism::InstanceVariableOrWriteNode).map(&:name)

  def probes(body) = body.grep(Prism::DefinedNode).map(&:value).grep(Prism::InstanceVariableReadNode).map(&:name)

  def detail = { site:, count: names.size }

  def evidence = names.map(&:to_s)
end
