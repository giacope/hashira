# frozen_string_literal: true

require "prism"

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
    absolved? || working? || nested.any?(&:legitimate?)
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
    !COMPARISONS.include?(call.name) && reads(Hashira::Analysis::NodeWalk.collect(call)).any?
  end

  def reads(nodes) = nodes.grep(Prism::LocalVariableReadNode).select { it.name == @name }
end
