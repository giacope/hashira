# frozen_string_literal: true

require "prism"
require_relative "rule"

class Hashira::Smells::Gated::UnreachableRescue < Hashira::Smells::Gated::Rule
  REQUIRES = %i[no_const_missing no_eval].freeze

  private

  def considers?(_type) = !blind?

  def subjects(type) = type.defs.flat_map { snares(it) }

  def snares(method)
    Hashira::Smells::Scope.inside(method.node).grep(Prism::RescueNode)
      .flat_map(&:exceptions).filter_map { stale(method, it) }
  end

  def stale(method, node)
    caught = family.sole(Hashira::Analysis::Syntax.segments(node))
    [method, caught] if caught && !thrown?(caught)
  end

  def thrown?(caught) = raised.any? { family.bloodline(it).include?(caught.name) }

  def raised = @_raised ||= flung.filter_map { family.sole(Hashira::Analysis::Syntax.segments(thrower(it))) }

  def blind? = flung.any? { muddy?(it) }

  def muddy?(call)
    given = call.arguments&.arguments&.first
    given && !given.is_a?(Prism::StringNode) && Hashira::Analysis::Syntax.segments(thrower(call)).empty?
  end

  def thrower(call)
    given = call.arguments&.arguments&.first
    given.is_a?(Prism::CallNode) && given.name == :new ? given.receiver : given
  end

  def flung
    @_flung ||= trees.each_value.flat_map { Hashira::Analysis::NodeWalk.collect(it) }
      .grep(Prism::CallNode).select { it.name == :raise && !it.receiver }
  end

  def entry(_type, pair) = aimed(pair)
end
