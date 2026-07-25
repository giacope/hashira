# frozen_string_literal: true

require "prism"

module Hashira
  module Complexity
    class CognitiveScore
      HANDLERS = {
        Prism::IfNode => :on_if,
        Prism::UnlessNode => :on_nester,
        Prism::WhileNode => :on_nester,
        Prism::UntilNode => :on_nester,
        Prism::ForNode => :on_nester,
        Prism::CaseNode => :on_nester,
        Prism::CaseMatchNode => :on_nester,
        Prism::BeginNode => :on_begin,
        Prism::AndNode => :on_boolean,
        Prism::OrNode => :on_boolean,
        Prism::BlockNode => :on_block,
        Prism::CallNode => :on_call
      }.freeze

      LABELS = {
        Prism::UnlessNode => "unless", Prism::WhileNode => "while",
        Prism::UntilNode => "until", Prism::ForNode => "for",
        Prism::CaseNode => "case", Prism::CaseMatchNode => "case"
      }.freeze

      def initialize(def_node)
        @increments = []
        @calls = 0
        visit(def_node.body, 0)
      end

      attr_reader :increments, :calls

      def total = @increments.sum(&:cost)

      def visit(node, nesting)
        return unless node

        send(HANDLERS.fetch(node.class, :descend), node, nesting)
      end

      def add(node, cost, label)
        @increments << Increment.new(line: node.location.start_line, cost:, label:)
      end

      private

      def descend(node, nesting) = node.compact_child_nodes.each { visit(it, nesting) }

      def on_call(node, nesting)
        @calls += 1
        descend(node, nesting)
      end

      def on_block(node, nesting) = node.compact_child_nodes.each { visit(it, nesting + 1) }

      def on_nester(node, nesting)
        add(node, 1 + nesting, LABELS.fetch(node.class))
        node.compact_child_nodes.each { visit(it, nesting + 1) }
      end

      def on_if(node, nesting) = IfChain.new(self).apply(node, nesting)

      def on_begin(node, nesting) = RescueScan.new(self).apply(node, nesting)

      def on_boolean(node, nesting) = BooleanRun.new(self).apply(node, nesting)
    end
  end
end
