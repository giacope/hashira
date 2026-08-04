# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module Syntax
      module_function

      def segments(node)
        case node
        when Prism::ConstantReadNode then [node.name.to_s]
        when Prism::ConstantPathNode then segments(node.parent) + label(node)
        else []
        end
      end

      def label(node) = [node.name.to_s]

      def cbase?(node)
        return false unless node.is_a?(Prism::ConstantPathNode)
        parent = node.parent
        !parent || cbase?(parent)
      end

      def anchor(stack, segments, roots)
        return (stack.last || []) + segments if segments.length < 2 || !roots
        base = stack.reverse_each.find { roots.include?(it + segments.first(1)) }
        base ? base + segments : hoist(stack, segments, roots)
      end

      def hoist(stack, segments, roots)
        roots.include?(segments.first(1)) ? segments : (stack.last || []) + segments
      end

      def direct(type_node) = statements(type_node).grep(Prism::DefNode)

      def constants(type_node) = statements(type_node).grep(Prism::ConstantWriteNode)

      def statements(type_node)
        body = type_node.body
        body.is_a?(Prism::StatementsNode) ? body.body : [body]
      end
    end
  end
end
