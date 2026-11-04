# frozen_string_literal: true

module Hashira
  module Analysis
    class Reopen
      def initialize(node, receiver)
        @node = node
        @receiver = receiver
      end

      def walk(stack = [], roots: nil, &)
        full = resolve(Syntax.new(@receiver), stack, roots)
        yield(@node, full, stack, full)
        TypeWalk.new(@node.body).walk(stack, roots:, &)
      end

      private

      def resolve(read, stack, roots)
        segments = read.segments
        return segments if read.rooted? || !roots
        (stack.reverse_each.find { roots.include?(it + segments.first(1)) } || []) + segments
      end
    end
  end
end
