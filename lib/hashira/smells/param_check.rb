# frozen_string_literal: true

require "prism"

class Hashira::Smells::ParamCheck
  COMPARISONS = %i[== != =~].freeze

  FIXED = [
    Prism::SymbolNode, Prism::StringNode, Prism::IntegerNode, Prism::FloatNode, Prism::NilNode, Prism::TrueNode,
    Prism::FalseNode, Prism::RegularExpressionNode, Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  TRANSLATIONS = %i[t translate].freeze

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

  def literal?(branch)
    found = outcome(branch)
    found.one? && value?(found.first)
  end

  def outcome(branch)
    case branch
    when Prism::StatementsNode then branch.body
    when Prism::ElseNode, Prism::WhenNode then Array(branch.statements&.body)
    else [branch]
    end
  end

  def value?(node) = FIXED.include?(node.class) || translated?(node)

  def translated?(node)
    node.is_a?(Prism::CallNode) && TRANSLATIONS.include?(node.name) && keyed?(node)
  end

  def keyed?(call) = Hashira::Smells::Foreign::KEYS.include?(Array(call.arguments&.arguments).first.class)

  def reads(nodes) = nodes.grep(Prism::LocalVariableReadNode).select { it.name == @name }
end
