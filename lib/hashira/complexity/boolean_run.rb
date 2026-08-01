# frozen_string_literal: true

class Hashira::Complexity::BooleanRun
  def initialize(scorer)
    @scorer = scorer
  end

  def apply(node, nesting)
    @scorer.add(node, 1, "boolean")
    operands(node).each { @scorer.visit(it, nesting) }
  end

  private

  def operands(node)
    node.compact_child_nodes.flat_map { it.instance_of?(node.class) ? operands(it) : [it] }
  end
end
