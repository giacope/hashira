# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refs
  LOCALS = [Prism::LocalVariableReadNode, Prism::LocalVariableWriteNode].freeze

  SELVES = [
    Prism::SelfNode, Prism::SuperNode, Prism::ForwardingSuperNode,
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(definition)
    @node = definition
  end

  def ego = lines(:self).size

  def lines(name) = tallies.fetch(name, [])

  def envious
    peak = tallies.values.map(&:size).max
    names = tallies.filter_map { |name, sightings| name if sightings.size == peak }
    names.include?(:self) ? [] : names
  end

  private

  def tallies = @_tallies ||= sightings.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

  def sightings = Hashira::Smells::Scope.inside(@node).map { [holder(it), it.location.start_line] }.select(&:first)

  def holder(node)
    return :self if selfish?(node)
    return node.receiver.name if local?(node)
    node.name if node.is_a?(Prism::LocalVariableOperatorWriteNode)
  end

  def selfish?(node)
    SELVES.include?(node.class) || implicit?(node)
  end

  def implicit?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def local?(node) = node.is_a?(Prism::CallNode) && LOCALS.include?(node.receiver.class) && node.name != :new
end
