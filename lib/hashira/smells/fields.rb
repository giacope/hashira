# frozen_string_literal: true

require "prism"

class Hashira::Smells::Fields
  WRITES = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(nodes)
    @nodes = nodes
  end

  def minted
    @_minted ||= Hashira::Smells::Attributes.new(@nodes).writers.map { :"@#{it.to_s.delete_suffix("=")}" }
  end

  def of(node) = WRITES.include?(node.class) ? node.name : setter(node)

  def named(kinds) = @nodes.select { kinds.include?(it.class) }.map(&:name)

  private

  def setter(node)
    return unless node.is_a?(Prism::CallNode) && node.attribute_write? && node.receiver.is_a?(Prism::SelfNode)
    field = :"@#{node.name.to_s.delete_suffix("=")}"
    field if minted.include?(field)
  end
end
