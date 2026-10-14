# frozen_string_literal: true

require "prism"

class Hashira::Complexity::Hollow
  CALLS = 2

  def initialize(node)
    @node = node
  end

  def hollow? = lone.is_a?(Prism::CallNode) && plain? && Hashira::Complexity::CognitiveScore.new(@node).total.zero?

  private

  def lone = statements.one? && statements.first

  def statements = @node.body.is_a?(Prism::StatementsNode) ? @node.body.body : []

  def plain? = inner.count { it.is_a?(Prism::CallNode) } <= CALLS && inner.none? { blocked?(it) }

  def blocked?(node) = node.is_a?(Prism::BlockNode) && node.body

  def inner = @_inner ||= Hashira::Analysis::NodeWalk.collect(lone)
end
