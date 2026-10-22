# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class TypeWalk
      MARKERS = %i[public private protected module_function].freeze

      CLASS_LEVEL = :ClassMethods

      def initialize(node)
        @node = node
      end

      def sections = Visibility.new(@node).entries

      def type? = @node.is_a?(Prism::ClassNode) || @node.is_a?(Prism::ModuleNode)

      def walk(stack = [], roots: nil, &)
        return descend(@node, stack, roots, &) unless type?
        full = Syntax.new(@node.constant_path).place(stack, roots)
        yield(@node, full, stack)
        descend(@node.body, stack + [full], roots, &)
      end

      private

      def descend(node, stack, roots, &)
        (node ? node.compact_child_nodes : []).each { TypeWalk.new(it).walk(stack, roots:, &) }
      end
    end
  end
end
