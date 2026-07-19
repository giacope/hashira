# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module References
      module_function

      def list(tree)
        each_sighting(tree).map(&:first)
      end

      def each_sighting(tree)
        [].tap { collect(tree, _1) }
      end

      def collect(node, accumulator)
        return unless node
        return accumulator << [Syntax.path_segments(node), node.location.start_line] if constant?(node)

        branches(node).each { collect(_1, accumulator) }
      end

      def constant?(node) = node.is_a?(Prism::ConstantPathNode) || node.is_a?(Prism::ConstantReadNode)

      def branches(node)
        definition?(node) ? definition_branches(node) : node.compact_child_nodes
      end

      def definition?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      def definition_branches(node)
        superclass = node.is_a?(Prism::ClassNode) ? node.superclass : nil
        [superclass, node.body]
      end
    end
  end
end
