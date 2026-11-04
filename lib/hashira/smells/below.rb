# frozen_string_literal: true

class Hashira::Smells::Below
  def initialize(node)
    @node = node
  end

  def to_a = @node.compact_child_nodes.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }
end
