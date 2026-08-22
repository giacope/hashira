# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::AbstractStubGap < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_define_method no_method_missing].freeze

  ABSTRACT = "NotImplementedError"

  private

  def subjects(type) = family.leaf?(type) ? unmet(type) : []

  def unmet(type)
    answered = live(family.ancestry(type))
    stubs(type).reject { answered.include?(it.node.name) }
  end

  def stubs(type) = family.elders(type).flat_map(&:owned).select { stub?(it) }

  def live(kin) = kin.flat_map(&:owned).reject { stub?(it) }.map { it.node.name }

  def stub?(method) = raises?(sole(method))

  def sole(method)
    body = Hashira::Analysis::Syntax.statements(method.node).compact
    body.first if body.one?
  end

  def raises?(node)
    node.is_a?(Prism::CallNode) && node.name == :raise && abstract?(node)
  end

  def abstract?(node)
    Hashira::Analysis::NodeWalk.collect(node).any? { Hashira::Analysis::Syntax.segments(it).last == ABSTRACT }
  end

  def entry(type, stub) = about(type, [stub], sites(stub), names: named(stub))

  def sites(stub) = [stub.site]

  def named(stub) = [stub.node.name]
end
