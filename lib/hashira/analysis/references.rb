# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module References
      module_function

      def list(tree)
        sightings(tree).map(&:first)
      end

      def sightings(tree, roots = nil)
        [].tap { collect(tree, [], it, roots) }
      end

      def collect(node, nesting, accumulator, roots, home = nesting)
        return unless node
        return accumulator << sighting(node, nesting, home) if constant?(node)
        return enter(node, nesting, accumulator, roots) if definition?(node)
        node.compact_child_nodes.each { collect(it, nesting, accumulator, roots, home) }
      end

      def sighting(node, nesting, home)
        [Syntax.segments(node), node.location.start_line, Syntax.cbase?(node) ? nil : nesting, home]
      end

      def constant?(node) = node.is_a?(Prism::ConstantPathNode) || node.is_a?(Prism::ConstantReadNode)

      def definition?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      def enter(node, nesting, accumulator, roots)
        opened = nesting + [Syntax.anchor(nesting, Syntax.segments(node.constant_path), roots)]
        collect(node.superclass, nesting, accumulator, roots, opened) if node.is_a?(Prism::ClassNode)
        collect(node.body, opened, accumulator, roots)
      end
    end
  end
end
