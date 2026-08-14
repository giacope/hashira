# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refs
  SELVES = [
    Prism::SelfNode, Prism::SuperNode, Prism::ForwardingSuperNode,
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(def_node)
    @node = def_node
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
    case node
    when Prism::CallNode then named(node)
    when Prism::LocalVariableOperatorWriteNode then note(node.name, node)
    end
  end

  def selfish?(node)
    SELVES.include?(node.class) || implicit?(node)
  end

  def implicit?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def named(node)
    case (receiver = node.receiver)
    when Prism::SelfNode then note(:self, node)
    when Prism::LocalVariableReadNode, Prism::LocalVariableWriteNode
      note(receiver.name, node) unless node.name == :new
    end
  end

  def note(name, node) = (@_tallies[name] ||= []) << node.location.start_line
end
