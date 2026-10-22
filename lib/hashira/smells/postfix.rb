# frozen_string_literal: true

require "prism"
require_relative "scope"

# An if or unless written after its statement: its condition runs first,
# though the statement comes first in the source.
class Hashira::Smells::Postfix
  KINDS = [Prism::IfNode, Prism::UnlessNode].freeze

  def initialize(node)
    @node = node
  end

  def trailing? = KINDS.include?(@node.class) && @node.statements&.location&.start_offset == @node.location.start_offset

  def asks?(child) = trailing? && child.equal?(@node.predicate)

  def covers?(node) = Hashira::Smells::Scope.new(@node.predicate).covers?(node)

  def start = @node.location.start_offset
end
