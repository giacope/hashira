# frozen_string_literal: true

require "prism"

module Hashira
  module Analysis
    class Syntax
      SENDS = %i[send public_send __send__ method].freeze

      def initialize(node)
        @node = node
      end

      def segments
        case @node
        when Prism::ConstantReadNode then [@node.name.to_s]
        when Prism::ConstantPathNode then Syntax.new(@node.parent).segments + [@node.name.to_s]
        else []
        end
      end

      def static?
        case @node
        when Prism::ConstantReadNode then true
        when Prism::ConstantPathNode then anchored?
        else false
        end
      end

      def dynamic? = @node.is_a?(Prism::ConstantPathNode) && !static?

      def origin = @node.is_a?(Prism::CallNode) && @node.receiver ? Syntax.new(@node.receiver).origin : segments.first

      def rooted?
        return false unless @node.is_a?(Prism::ConstantPathNode)
        parent = @node.parent
        !parent || Syntax.new(parent).rooted?
      end

      def place(stack, roots) = rooted? ? segments : anchor(stack, segments, roots)

      def macro?(names) = @node.is_a?(Prism::CallNode) && names.include?(@node.name) && bare?

      def bare? = !@node.receiver && @node.arguments

      def direct = statements.grep(Prism::DefNode)

      def options = keywords.flat_map(&:elements).grep(Prism::AssocNode)

      def keywords = Array(@node.arguments&.arguments).grep(Prism::KeywordHashNode)

      def option(key) = options.find { Syntax.new(it.key).named?(key) }&.value

      def text = @node.unescaped.scrub

      def word? = @node.is_a?(Prism::StringNode) || @node.is_a?(Prism::SymbolNode)

      def symbol = text.to_sym

      def literal = (text if word?)

      def named?(key) = @node.is_a?(Prism::SymbolNode) && text == key.to_s

      def constants = statements.grep(Prism::ConstantWriteNode)

      def thaw = @node.is_a?(Prism::CallNode) && @node.name == :freeze ? @node.receiver : @node

      def statements
        body = @node.body
        body.is_a?(Prism::StatementsNode) ? body.body : [body]
      end

      private

      def anchored?
        parent = @node.parent
        !parent || Syntax.new(parent).static?
      end

      def anchor(stack, segments, roots)
        return (stack.last || []) + segments if segments.length < 2 || !roots
        base = stack.reverse_each.find { roots.include?(it + segments.first(1)) }
        base ? base + segments : hoist(stack, segments, roots)
      end

      def hoist(stack, segments, roots)
        roots.include?(segments.first(1)) ? segments : (stack.last || []) + segments
      end
    end
  end
end
