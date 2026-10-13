# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Calls
  def initialize(node)
    @node = node
  end

  def names = [@node.body].compact.flat_map { sent(it) }.uniq

  private

  def sent(node)
    return [] if node.is_a?(Prism::DefNode)
    (own?(node) ? [node.name] : []) + node.compact_child_nodes.flat_map { sent(it) }
  end

  def own?(node) = node.is_a?(Prism::CallNode) && [NilClass, Prism::SelfNode].include?(node.receiver.class)
end
