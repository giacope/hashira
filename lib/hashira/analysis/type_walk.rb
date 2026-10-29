# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class TypeWalk
      MARKERS = %i[public private protected module_function].freeze

      CLASS_LEVEL = :ClassMethods

      private_constant :MARKERS, :CLASS_LEVEL

      def initialize(node, block: false)
        @node = node
        @block = block
      end

      def sections = Visibility.new(@node).entries

      def written = Visibility.new(@node).written

      def dsl?(host = nil) = @node.is_a?(Prism::CallNode) && Block.new(@node, host).dsl?

      def apart? = @node.is_a?(Prism::CallNode) && Block.new(@node).apart?

      def type? = @block || @node.is_a?(Prism::ClassNode) || @node.is_a?(Prism::ModuleNode)

      def marker? = Syntax.new(@node).command?(MARKERS)

      def class_level? = @node.is_a?(Prism::ModuleNode) && @node.name == CLASS_LEVEL

      def walk(stack = [], roots: nil, &)
        return descend(@node, stack, roots, &) unless type?
        return adopt(stack, roots, &) if @block
        full = Syntax.new(@node.constant_path).place(stack, roots)
        yield(@node, full, stack, full)
        descend(@node.body, stack + [full], roots, &)
      end

      def beneath(stack, roots, &) = descend(@node.body, stack, roots, &)

      private

      def walker(child, stack)
        plain = TypeWalk.new(child)
        child.is_a?(Prism::CallNode) ? Block.new(child, @node).walker(stack, plain) : plain
      end

      def adopt(stack, roots, &)
        yield(@node, @block, stack, stack.last)
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
