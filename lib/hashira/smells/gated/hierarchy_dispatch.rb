# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::HierarchyDispatch < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_const_missing no_eval].freeze

  TESTS = %i[is_a? kind_of? instance_of?].freeze

  private

  def considers?(_type) = true

  def subjects(type) = type.owned.flat_map { probes(type, it) }

  def probes(type, method)
    named(method).filter_map { |node| pair(type, method, node) }
  end

  def named(method)
    body = Hashira::Smells::Scope.inside(method.node)
    body.grep(Prism::CallNode).filter_map { asked(it) } + body.grep(Prism::CaseNode).flat_map { arms(it) }
  end

  def asked(node) = (node.arguments&.arguments&.first if TESTS.include?(node.name))

  def arms(node) = node.conditions.grep(Prism::WhenNode).flat_map(&:conditions)

  def pair(type, method, node)
    other = family.sole(Hashira::Analysis::Syntax.segments(node))
    [method, other] if other && other.name != type.name && family.related?(type, other)
  end

  def entry(_type, pair) = aimed(pair)
end
