# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Calls
  SENDS = Hashira::Analysis::Syntax::SENDS

  def initialize(node)
    @node = node
  end

  def names = sent.uniq

  def sent = [@node.body].compact.flat_map { gathered(it) }

  private

  def gathered(node)
    return [] if node.is_a?(Prism::DefNode)
    (own?(node) ? [node.name, *aimed(node)] : []) + node.compact_child_nodes.flat_map { gathered(it) }
  end

  def own?(node) = node.is_a?(Prism::CallNode) && [NilClass, Prism::SelfNode].include?(node.receiver.class)

  def aimed(call)
    target = call.arguments&.arguments&.first
    SENDS.include?(call.name) && target.is_a?(Prism::SymbolNode) ? [Hashira::Analysis::Syntax.symbol(target)] : []
  end
end
