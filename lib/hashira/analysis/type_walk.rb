# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module TypeWalk
      module_function

      def roots(trees)
        trees.each_value.with_object(Set.new) { |tree, set| each(tree) { |_node, full| set << full } }
      end

      def each(node, stack = [], roots: nil, &)
        return descend(node, stack, roots, &) unless type?(node)
        full = Syntax.anchor(stack, Syntax.segments(node.constant_path), roots)
        yield(node, full)
        descend(node.body, stack + [full], roots, &)
      end

      def type?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      def descend(node, stack, roots, &)
        (node ? node.compact_child_nodes : []).each { each(it, stack, roots:, &) }
      end
    end
  end
end
