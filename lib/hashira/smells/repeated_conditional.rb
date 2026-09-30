# frozen_string_literal: true

require "prism"
require_relative "scope"

class Hashira::Smells::RepeatedConditional < Hashira::Smells::Check
  LIMIT = 2

  EXEMPT = "block_given?"

  LOCALS = [Prism::LocalVariableReadNode, Prism::ItLocalVariableReadNode].freeze

  SCOPES = (Hashira::Smells::Scope::FENCES + [Prism::BlockNode, Prism::LambdaNode]).freeze

  private

  def smelly? = subject.kind == :class && repeats.any?

  def repeats = @_repeats ||= tests.group_by { |test, region| same(test, region) }.values.select { it.size > LIMIT }

  def same(test, region) = [test.slice, (region if local?(test))]

  def tests = regions.flat_map { |region| predicates(region).map { [it, region] } }.reject { |test, _| exempt?(test) }

  def exempt?(test) = test.slice == EXEMPT

  def regions = subject.nodes.flat_map { [it] + Hashira::Smells::Scope.sweep(it).select { SCOPES.include?(it.class) } }

  def predicates(region) = Hashira::Smells::Scope.below(region, SCOPES).filter_map { predicate(it) }

  def predicate(node)
    node.predicate if node.is_a?(Prism::IfNode) || node.is_a?(Prism::UnlessNode) || node.is_a?(Prism::CaseNode)
  end

  def local?(test) = ([test] + Hashira::Smells::Scope.inside(test)).any? { LOCALS.include?(it.class) }

  def detail = { site:, count: repeats.map(&:size).max }

  def evidence = repeats.map { |pairs| row(pairs.map(&:first)) }

  def row(nodes)
    "#{nodes.first.slice} × #{nodes.size} (lines #{nodes.map { |node| node.location.start_line }.uniq.sort.join(", ")})"
  end
end
