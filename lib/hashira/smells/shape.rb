# frozen_string_literal: true

require "digest"
require "prism"

module Hashira::Smells::Shape
  LENGTH = 12

  FIELDS = %i[name unescaped value binary_operator].freeze

  module_function

  def of(nodes) = Digest::SHA256.hexdigest(marks(nodes).inspect).slice(0, LENGTH)

  def marks(nodes) = nodes.flat_map { Hashira::Analysis::NodeWalk.collect(it) }.map { mark(it) }

  def mark(node) = [node.type, *node.deconstruct_keys(FIELDS).values_at(*FIELDS).compact.grep_v(Prism::Node)]
end
