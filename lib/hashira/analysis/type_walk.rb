# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class TypeWalk
      MARKERS = %i[public private protected module_function].freeze

      CLASS_LEVEL = :ClassMethods

      def initialize(node, block: false, opens: nil)
        @node = node
        @block = block
        @opens = opens
      end

      def sections = Visibility.new(@node).entries

      def written = Visibility.new(@node).written

      def dsl?(host = nil) = @node.is_a?(Prism::CallNode) && Block.new(@node, host).dsl?

      def type? = @block || @opens || @node.is_a?(Prism::ClassNode) || @node.is_a?(Prism::ModuleNode)

      def walk(stack = [], roots: nil, &)
        return descend(@node, stack, roots, &) unless type?
        return adopt(stack, roots, &) if @block
        return reopen(stack, roots, &) if @opens
        full = Syntax.new(@node.constant_path).place(stack, roots)
        yield(@node, full, stack, full)
        descend(@node.body, stack + [full], roots, &)
      end

      private

      def walker(child, stack)
        (Block.new(child, @node).walker(stack) if child.is_a?(Prism::CallNode)) || TypeWalk.new(child)
      end

      def reopen(stack, roots, &)
        full = resolve(Syntax.new(@opens), stack, roots)
        yield(@node, full, stack, full)
        descend(@node.body, stack, roots, &)
      end

      def resolve(read, stack, roots)
        segments = read.segments
        return segments if read.rooted? || !roots
        (stack.reverse_each.find { roots.include?(it + segments.first(1)) } || []) + segments
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
