# frozen_string_literal: true

require "prism"
require_relative "mapping"

class Hashira::Smells::ParamCheck
  COMPARISONS = %i[== != =~].freeze

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
    @_nested ||= Hashira::Smells::Conditionals.new(branches).nested.map { self.class.new(it, @name) }
  end

  def branches = Hashira::Smells::Conditions.new(@node).branches

  def predicate
    @_predicate ||= spread(Hashira::Smells::Conditions.new(@node).condition)
  end

  def spread(condition) = condition ? Hashira::Analysis::NodeWalk.new(condition).collect : []

  def tested = reads(predicate)

  def working?
    reads(Hashira::Smells::Conditionals.new(branches.compact).plain).any?
  end

  def absolved?
    predicate.grep(Prism::CallNode).any? { absolves?(it) }
  end

  def absolves?(call)
    return measured?(call) if COMPARISONS.include?(call.name)
    reads(Hashira::Analysis::NodeWalk.new(call).collect).any?
  end

  def measured?(call)
    sides = [call.receiver, *call.arguments&.arguments]
    others = sides - reads(sides)
    others.size < sides.size && others.any? { !Hashira::Analysis::Syntax::Value.new(it).fixed? }
  end

  def mapped? = tested.any? && !Hashira::Smells::Conditions.new(@node).couple? && branches.compact.all? { literal?(it) }

  def literal?(branch) = Hashira::Smells::Mapping.new(branch).literal? || Hashira::Smells::Mapping.new(branch).built?

  def reads(nodes) = nodes.grep(Prism::LocalVariableReadNode).select { it.name == @name }
end
