# frozen_string_literal: true

require "prism"
require_relative "tails"

class Hashira::Smells::Nulls
  PICKS = %i[find detect first last [] dig min_by max_by find_by find_index index presence].freeze

  OPEN = { Prism::IfNode => :subsequent, Prism::UnlessNode => :else_clause, Prism::CaseNode => :else_clause }.freeze

  FLOW = Hashira::Smells::Tails.new

  KEPT = [Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode].freeze

  HASHES = %w[Hash ::Hash].freeze

  BARE = [Prism::NilNode, Prism::KeywordHashNode].freeze

  def initialize(trees)
    @trees = trees
  end

  def answer?(path, name) = index.fetch("#{path}##{name}", []).any? { nullable?(it) }

  private

  def index
    @_index ||= @trees.flat_map { defs(it) }.group_by(&:first).transform_values { it.map(&:last) }
  end

  def defs(tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk do |node, full|
      defaulted = defaulted(node)
      Hashira::Analysis::TypeWalk.new(node).sections.each do |definition, section|
        next if definition.receiver || section == :singleton
        found << ["#{full.join("::")}##{definition.name}", [definition, defaulted]]
      end
    end
    found
  end

  def defaulted(type)
    writes = Hashira::Smells::Scope.new(type).sweep.select { KEPT.include?(it.class) }.group_by(&:name)
    writes.select { |_, kept| kept.all? { defaults?(it.value) } }.keys.to_set
  end

  def defaults?(value)
    return false unless value.is_a?(Prism::CallNode) && value.name == :new && HASHES.include?(value.receiver&.slice)
    block = value.block
    block.is_a?(Prism::BlockNode) ? computes?(block) : Array(value.arguments&.arguments).any? { !BARE.include?(it.class) }
  end

  def computes?(block)
    tails = FLOW.reach(Hashira::Analysis::Syntax::Body.new(block).to_a.compact.last(1)).flat_map { stored(it) }
    tails.any? && tails.none? { open?(it) }
  end

  def stored(node)
    return [node] unless node in Prism::CallNode[name: :[]=, arguments: Prism::ArgumentsNode[arguments: [*, value]]]
    FLOW.reach([value]).to_a
  end

  def nullable?((definition, defaulted))
    held = Hashira::Analysis::Syntax::Body.new(definition).to_a.compact
    held.empty? || returns?(definition) || FLOW.reach(held.last(1)).any? { open?(it) && !kept?(it, defaulted) }
  end

  def kept?(node, defaulted)
    node.is_a?(Prism::CallNode) && node.name == :[] && node.receiver.is_a?(Prism::InstanceVariableReadNode) &&
      defaulted.include?(node.receiver.name)
  end

  def returns?(definition)
    Hashira::Smells::Scope.new(definition).inside.grep(Prism::ReturnNode).any? { bare?(it.arguments) }
  end

  def bare?(arguments) = Array(arguments&.arguments).all?(Prism::NilNode)

  def open?(node)
    case node
    when Prism::NilNode then true
    when Prism::CallNode then node.safe_navigation? || PICKS.include?(node.name)
    else OPEN.key?(node.class) && node.public_send(OPEN.fetch(node.class)).nil?
    end
  end
end
