# frozen_string_literal: true

require "prism"

class Hashira::Smells::RepeatedConditional < Hashira::Smells::Check
  LIMIT = 2

  def self.judge? = true

  private

  def smelly? = subject.kind == :class && repeats.any?

  def repeats
    @repeats ||= predicates.group_by(&:slice).except("block_given?").select { |_test, nodes| nodes.size > LIMIT }
  end

  def predicates = Hashira::Smells::Scope.sweep(subject.node).filter_map { predicate(it) }

  def predicate(node)
    node.predicate if node.is_a?(Prism::IfNode) || node.is_a?(Prism::UnlessNode) || node.is_a?(Prism::CaseNode)
  end

  def detail = { site:, count: repeats.values.map(&:size).max }

  def evidence = repeats.map { |test, nodes| row(test, nodes) }

  def row(test, nodes)
    "#{test} × #{nodes.size} (lines #{nodes.map { |node| node.location.start_line }.join(", ")})"
  end
end
