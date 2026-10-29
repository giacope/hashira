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

  class Walk
    def initialize(nesting = 0)
      @nesting = nesting
    end

    def visit(node)
      node ? __send__(HANDLERS.fetch(node.class, :descend), node) : Hashira::Complexity::Charges.none
    end

    def charge(node, label) = Hashira::Complexity::Charges.mark(node, 1 + @nesting, label)

    def deeper = Walk.new(@nesting + 1)

    private

    def descend(node) = node.compact_child_nodes.sum(Hashira::Complexity::Charges.none) { visit(it) }

    def inside(node)
      walk = deeper
      node.compact_child_nodes.sum(Hashira::Complexity::Charges.none) { walk.visit(it) }
    end

    def on_call(node) = Hashira::Complexity::Charges.call + descend(node)

    def on_block(node) = inside(node)

    def on_nester(node) = charge(node, LABELS.fetch(node.class)) + inside(node)

    def on_if(node) = Hashira::Complexity::IfChain.new(self).apply(node)

    def on_unless(node) = Hashira::Complexity::IfChain.new(self).negated(node)

    def on_begin(node) = Hashira::Complexity::RescueScan.new(self).apply(node)

    def on_rescue(node) = Hashira::Complexity::RescueScan.new(self).modifier(node)

    def on_boolean(node) = Hashira::Complexity::BooleanRun.new(self).apply(node)
  end

  def initialize(node, walk = Walk.new)
    @node = node
    @walk = walk
  end

  def increments = walked.to_a

  def calls = walked.count

  def total = walked.total

  def score(subject, file, extra)
    charges = Hashira::Complexity::Charges.new(increments + extra, calls)
    Hashira::Complexity::MethodScore.new(subject, file, @node.location.start_line, charges)
  end

  private

  def walked = @_walked ||= @walk.visit(@node.body)
end
