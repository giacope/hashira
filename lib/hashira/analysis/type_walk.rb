# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module TypeWalk
      module_function

      def each_definition(node, prefix = [], &)
        return each_child_definition(node, prefix, &) unless type_node?(node)

        full = prefix + Syntax.path_segments(node.constant_path)
        yield(node, full)
        each_child_definition(node.body, full, &)
      end

      def type_node?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      def each_child_definition(node, prefix, &)
        children = node ? node.compact_child_nodes : []
        children.each { each_definition(it, prefix, &) }
      end
    end
  end
end
