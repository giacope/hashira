# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    module Syntax
      SENDS = %i[send public_send __send__ method].freeze

      module_function

      def segments(node)
        case node
        when Prism::ConstantReadNode then [node.name.to_s]
        when Prism::ConstantPathNode then segments(node.parent) + label(node)
        else []
        end
      end

      def label(node) = [node.name.to_s]

      def static?(node)
        case node
        when Prism::ConstantReadNode then true
        when Prism::ConstantPathNode then anchored?(node.parent)
        else false
        end
      end

      def anchored?(parent) = !parent || static?(parent)

      def dynamic?(node) = node.is_a?(Prism::ConstantPathNode) && !static?(node)

      def rooted?(node)
        return false unless node.is_a?(Prism::ConstantPathNode)
        parent = node.parent
        !parent || rooted?(parent)
      end

      def place(stack, path, roots) = rooted?(path) ? segments(path) : anchor(stack, segments(path), roots)

      def anchor(stack, segments, roots)
        return (stack.last || []) + segments if segments.length < 2 || !roots
        base = stack.reverse_each.find { roots.include?(it + segments.first(1)) }
        base ? base + segments : hoist(stack, segments, roots)
      end

      def hoist(stack, segments, roots)
        roots.include?(segments.first(1)) ? segments : (stack.last || []) + segments
      end

      def macro?(node, names) = node.is_a?(Prism::CallNode) && names.include?(node.name) && bare?(node)

      def bare?(call) = !call.receiver && call.arguments

      def direct(type) = statements(type).grep(Prism::DefNode)

      def options(call) = keywords(call).flat_map(&:elements).grep(Prism::AssocNode)

      def keywords(call) = Array(call.arguments&.arguments).grep(Prism::KeywordHashNode)

      def option(call, key) = options(call).find { named?(it.key, key) }&.value

      def text(node) = node.unescaped.scrub

      def word?(node) = node.is_a?(Prism::StringNode) || node.is_a?(Prism::SymbolNode)

      def symbol(node) = text(node).to_sym

      def symbol_names(nodes) = nodes.grep(Prism::SymbolNode).map { text(it) }

      def named?(node, key) = node.is_a?(Prism::SymbolNode) && text(node) == key.to_s

      def constants(type) = statements(type).grep(Prism::ConstantWriteNode)

      def statements(type)
        body = type.body
        body.is_a?(Prism::StatementsNode) ? body.body : [body]
      end
    end
  end
end
