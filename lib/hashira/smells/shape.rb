# frozen_string_literal: true

require "digest"
require "prism"

class Hashira::Smells::Shape
  LENGTH = 12

  FIELDS = %i[name unescaped value binary_operator].freeze

  def initialize(nodes)
    @nodes = nodes
  end

  def of = Digest::SHA256.hexdigest(marks.inspect).slice(0, LENGTH)

  private

  def marks = @nodes.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }.map { mark(it) }

  def mark(node) = [node.type, *node.deconstruct_keys(FIELDS).values_at(*FIELDS).compact.grep_v(Prism::Node)]
end
