# frozen_string_literal: true

require "prism"

class Hashira::Smells::StateSprawl < Hashira::Smells::Check
  LIMIT = 4

  COUNTED = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  TOUCHED = (COUNTED + [Prism::InstanceVariableReadNode, Prism::InstanceVariableOrWriteNode]).freeze

  CONSTRUCTOR = :initialize

  private

  def smelly? = subject.kind == :class && weight > LIMIT && !cohesive?

  def weight = names.size + parked.size

  def parked = @_parked ||= names.intersection(written(strays)) - written(founders)

  def strays = methods.reject(&:receiver) - founders

  def written(methods) = sweeps(methods).select { COUNTED.include?(it.class) }.map(&:name)

  def founders = methods.select { founding.include?(it.name) }

  def founding = @_founding ||= [CONSTRUCTOR] + helpers.map(&:name)

  def helpers = sweeps(constructors).grep(Prism::CallNode).reject(&:receiver)

  def sweeps(methods) = methods.flat_map { within(it) }

  def within(method) = nodes.select { Hashira::Smells::Scope.covers?(method, it) }

  def constructors = methods.select { it.name == CONSTRUCTOR }

  def methods = @_methods ||= nodes.grep(Prism::DefNode)

  def cohesive? = parked.empty? && clusters.one?

  def clusters = touches.reduce(names.zip) { |groups, used| fuse(groups, used) }

  def touches = (methods - constructors).map { touched(it) }.reject(&:empty?)

  def touched(method) = within(method).select { TOUCHED.include?(it.class) }.map(&:name) & names

  def fuse(groups, used)
    joined, apart = groups.partition { it.intersect?(used) }
    apart + [joined.flatten]
  end

  def names
    @_names ||= writes.map(&:name).uniq.reject { it.start_with?("@_") || memoized?(it) }.sort
  end

  def nodes = @_nodes ||= subject.sweep

  def writes = @_writes ||= nodes.select { COUNTED.include?(it.class) }

  def memoized?(name) = lazy?(name) && writes.select { it.name == name }.all? { blank?(it) || guarded?(it) }

  def lazy?(name) = cached.include?(name) || probed.include?(name)

  def probed = @_probed ||= probes(nodes)

  def blank?(write) = write.is_a?(Prism::InstanceVariableWriteNode) && write.value.is_a?(Prism::NilNode)

  def guarded?(write) = guarded.any? { it.equal?(write) }

  def guarded = @_guarded ||= methods.flat_map { shielded(Hashira::Smells::Scope.sweep(it)) }

  def shielded(body)
    probed = probes(body)
    body.select { COUNTED.include?(it.class) && probed.include?(it.name) }
  end

  def cached = @_cached ||= nodes.grep(Prism::InstanceVariableOrWriteNode).map(&:name)

  def probes(body) = body.grep(Prism::DefinedNode).map(&:value).grep(Prism::InstanceVariableReadNode).map(&:name)

  def detail = { site:, count: names.size }

  def evidence = names.map(&:to_s)
end
