# frozen_string_literal: true

require "prism"

class Hashira::Complexity::CognitiveScore
  HANDLERS = { Prism::IfNode => :on_if, Prism::BeginNode => :on_begin, Prism::BlockNode => :on_block }
    .merge(Prism::AndNode => :on_boolean, Prism::OrNode => :on_boolean, Prism::CallNode => :on_call)
    .merge(Prism::UnlessNode => :on_nester, Prism::WhileNode => :on_nester, Prism::UntilNode => :on_nester)
    .merge(Prism::ForNode => :on_nester, Prism::CaseNode => :on_nester, Prism::CaseMatchNode => :on_nester)
    .freeze

  LABELS = { Prism::UnlessNode => "unless", Prism::WhileNode => "while", Prism::UntilNode => "until" }
    .merge(Prism::ForNode => "for", Prism::CaseNode => "case", Prism::CaseMatchNode => "case").freeze

  def initialize(node)
    @node = node
  end

  def increments
    walked
    @_increments
  end

  def calls
    walked
    @_calls
  end

  def nesting
    walked
    @_nesting
  end

  def total = increments.sum(&:cost)

  def visit(node)
    return unless node
    __send__(HANDLERS.fetch(node.class, :descend), node)
  end

  def add(node, cost, label)
    @_increments << Hashira::Complexity::Increment.new(line: node.location.start_line, cost:, label:)
  end

  def deeper
    @_nesting += 1
    yield
    @_nesting -= 1
  end

  private

  def walked
    return if @_walked
    @_walked = true
    blank
    visit(@node.body)
  end

  def blank
    @_increments = []
    @_calls = 0
    @_nesting = 0
  end

  def descend(node) = node.compact_child_nodes.each { visit(it) }

  def on_call(node)
    @_calls += 1
    descend(node)
  end

  def on_block(node) = deeper { descend(node) }

  def on_nester(node)
    add(node, 1 + @_nesting, LABELS.fetch(node.class))
    deeper { descend(node) }
  end

  def on_if(node) = Hashira::Complexity::IfChain.new(self).apply(node)

  def on_begin(node) = Hashira::Complexity::RescueScan.new(self).apply(node)

  def on_boolean(node) = Hashira::Complexity::BooleanRun.new(self).apply(node)
end
