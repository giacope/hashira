# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module TypeWalk
      MARKERS = %i[public private protected module_function].freeze

      CLASS_LEVEL = :ClassMethods

      module_function

      def sections(type) = Visibility.new(type).entries

      def parted(trees, parts) = Set.new.compare_by_identity.merge(trees.flat_map { members(it, parts) })

      def members(tree, parts) = to_enum(:each, tree).flat_map { |type, *| chosen(type, parts) }

      def chosen(type, parts) = sections(type).filter_map { |node, part| node if parts.include?(part) }

      def roots(trees)
        trees.each_value.with_object(Set.new) { |tree, set| each(tree) { |_node, full| set << full } }
      end

      def each(node, stack = [], roots: nil, &)
        return descend(node, stack, roots, &) unless type?(node)
        full = Syntax.place(stack, node.constant_path, roots)
        yield(node, full, stack)
        descend(node.body, stack + [full], roots, &)
      end

      def type?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

      def descend(node, stack, roots, &)
        (node ? node.compact_child_nodes : []).each { each(it, stack, roots:, &) }
      end
    end
  end
end
