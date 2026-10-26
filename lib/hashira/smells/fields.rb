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
    @_minted ||= Hashira::Smells::Attributes.new(@nodes).declared(Hashira::Smells::Attributes::WRITERS).map { :"@#{it}" }
  end

  def of(node) = WRITES.include?(node.class) ? node.name : setter(node)

  private

  def setter(node)
    return unless node.is_a?(Prism::CallNode) && node.attribute_write? && node.receiver.is_a?(Prism::SelfNode)
    field = :"@#{node.name.to_s.delete_suffix("=")}"
    field if minted.include?(field)
  end
end
