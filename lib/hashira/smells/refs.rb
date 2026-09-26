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

  def tallies
    return @_tallies if @_tallies
    @_tallies = {}
    Hashira::Smells::Scope.inside(@node).each { record(it) }
    @_tallies
  end

  def record(node)
    return note(:self, node) if selfish?(node)
    return note(node.receiver.name, node) if local?(node)
    note(node.name, node) if node.is_a?(Prism::LocalVariableOperatorWriteNode)
  end

  def selfish?(node)
    SELVES.include?(node.class) || implicit?(node)
  end

  def implicit?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def local?(node) = node.is_a?(Prism::CallNode) && LOCALS.include?(node.receiver.class) && node.name != :new

  def note(name, node) = (@_tallies[name] ||= []) << node.location.start_line
end
