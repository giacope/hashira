# frozen_string_literal: true

require "prism"

class Hashira::Smells::Marks
  FIELDS = %i[name unescaped value binary_operator].freeze

  private_constant :FIELDS

  def initialize(node)
    @node = node
  end

  def to_a = Hashira::Analysis::NodeWalk.new(@node).collect.map { mark(it) }

  private

  def mark(node) = [node.type, *node.deconstruct_keys(FIELDS).values_at(*FIELDS).compact.grep_v(Prism::Node)]
end
