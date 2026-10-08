# frozen_string_literal: true

require "prism"
require_relative "mapping"

class Hashira::Smells::ParamCheck
  COMPARISONS = %i[== != =~].freeze

  FIXED = Hashira::Smells::Mapping::FIXED

  def initialize(node, name)
    @node = node
    @name = name
  end

  def matches
    return [] if legitimate?
    nested.flat_map(&:matches) + tested
  end

  def legitimate?
    absolved? || working? || mapped? || nested.any?(&:legitimate?)
  end

  private

  def nested
    @_nested ||= Hashira::Smells::Conditions.nested(branches).map { self.class.new(it, @name) }
  end

  def branches = Hashira::Smells::Conditions.branches(@node)

  def predicate
    @_predicate ||= spread(Hashira::Smells::Conditions.condition(@node))
  end

  def spread(condition) = condition ? Hashira::Analysis::NodeWalk.collect(condition) : []

  def tested = reads(predicate)

  def working?
    reads(branches.compact.flat_map { Hashira::Smells::Conditions.plain(it) }).any?
  end

  def absolved?
    predicate.grep(Prism::CallNode).any? { absolves?(it) }
  end

  def absolves?(call)
    return measured?(call) if COMPARISONS.include?(call.name)
    reads(Hashira::Analysis::NodeWalk.collect(call)).any?
  end

  def measured?(call)
    sides = [call.receiver, *call.arguments&.arguments]
    others = sides - reads(sides)
    others.size < sides.size && others.any? { !FIXED.include?(it.class) }
  end

  def mapped? = tested.any? && !Hashira::Smells::Conditions.couple?(@node) && branches.compact.all? { literal?(it) }

  def literal?(branch) = Hashira::Smells::Mapping.literal?(branch)

  def reads(nodes) = nodes.grep(Prism::LocalVariableReadNode).select { it.name == @name }
end
