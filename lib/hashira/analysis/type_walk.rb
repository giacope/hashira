# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class TypeWalk
      MARKERS = %i[public private protected module_function].freeze

      CLASS_LEVEL = :ClassMethods

      def initialize(node, block: false)
        @node = node
        @block = block
      end

      def sections = Visibility.new(@node).entries

      def dsl? = @node.is_a?(Prism::CallNode) && Block.new(@node).dsl?

      def type? = @block || @node.is_a?(Prism::ClassNode) || @node.is_a?(Prism::ModuleNode)

      def walk(stack = [], roots: nil, &)
        return descend(@node, stack, roots, &) unless type?
        return adopt(stack, roots, &) if @block
        full = Syntax.new(@node.constant_path).place(stack, roots)
        yield(@node, full, stack, full)
        descend(@node.body, stack + [full], roots, &)
      end

      private

      def walker(child, stack)
        return TypeWalk.new(child) unless stack.any? && TypeWalk.new(child).dsl?
        TypeWalk.new(child.block, block: Block.new(child).name)
      end

      def adopt(stack, roots, &)
        yield(@node, stack.last + [@block], stack, stack.last)
        descend(@node.body, stack, roots, &)
      end

      def descend(node, stack, roots, &)
        (node ? node.compact_child_nodes : []).each do |child|
          next if child.is_a?(Prism::DefNode)
          walker(child, stack).walk(stack, roots:, &)
        end
      end
    end
  end
end
