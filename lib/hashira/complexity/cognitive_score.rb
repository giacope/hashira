# frozen_string_literal: true

require "prism"

class Hashira::Complexity::CognitiveScore
  HANDLERS = { Prism::IfNode => :on_if, Prism::BeginNode => :on_begin, Prism::BlockNode => :on_block }
    .merge(Prism::LambdaNode => :on_block)
    .merge(Prism::AndNode => :on_boolean, Prism::OrNode => :on_boolean, Prism::CallNode => :on_call)
    .merge(Prism::UnlessNode => :on_unless, Prism::WhileNode => :on_nester, Prism::UntilNode => :on_nester)
    .merge(Prism::ForNode => :on_nester, Prism::CaseNode => :on_nester, Prism::CaseMatchNode => :on_nester)
    .merge(Prism::RescueModifierNode => :on_rescue)
    .freeze

  LABELS = { Prism::WhileNode => "while", Prism::UntilNode => "until" }
    .merge(Prism::ForNode => "for", Prism::CaseNode => "case", Prism::CaseMatchNode => "case").freeze

  Walk =
    Data.define(:increments, :calls, :levels) do
      def nesting = levels.size

      def visit(node)
        return unless node
        __send__(HANDLERS.fetch(node.class, :descend), node)
      end

      def add(node, cost, label)
        increments << Hashira::Complexity::Increment.new(line: node.location.start_line, cost:, label:)
      end

      def deeper
        levels.push(nil)
        yield
        levels.pop
      end
      private
      def descend(node) = node.compact_child_nodes.each { visit(it) }

      def on_call(node)
        calls.push(nil)
        descend(node)
      end

      def on_block(node) = deeper { descend(node) }

      def on_nester(node)
        add(node, 1 + nesting, LABELS.fetch(node.class))
        deeper { descend(node) }
      end

      def on_if(node) = Hashira::Complexity::IfChain.new(self).apply(node)

      def on_unless(node) = Hashira::Complexity::IfChain.new(self).negated(node)

      def on_begin(node) = Hashira::Complexity::RescueScan.new(self).apply(node)

      def on_rescue(node) = Hashira::Complexity::RescueScan.new(self).modifier(node)

      def on_boolean(node) = Hashira::Complexity::BooleanRun.new(self).apply(node)
    end

  def initialize(node)
    @node = node
  end

  def increments = walked.increments

  def calls = walked.calls.size

  def total = increments.sum(&:cost)

  def tallies(extra)
    all = increments + extra
    { cognitive: all.sum(&:cost), calls:, increments: all }
  end

  private

  def walked = @_walked ||= Walk.new(increments: [], calls: [], levels: []).tap { it.visit(@node.body) }
end
