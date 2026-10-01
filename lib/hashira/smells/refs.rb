# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refs
  Local = Data.define(:name, :scope)

  SELF = Local.new(:self, nil)

  LOCALS = [Prism::LocalVariableReadNode, Prism::LocalVariableWriteNode].freeze

  SCOPES = [Prism::BlockNode, Prism::LambdaNode].freeze

  SELVES = [
    Prism::SelfNode, Prism::SuperNode, Prism::ForwardingSuperNode,
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(definition, vocabulary)
    @node = definition
    @vocabulary = vocabulary
  end

  def ego = lines(SELF).size

  def lines(holder) = tallies.fetch(holder, [])

  def envious
    peak = tallies.values.map(&:size).max
    holders = tallies.filter_map { |holder, sightings| holder if sightings.size == peak }
    holders.include?(SELF) ? [] : holders
  end

  private

  def tallies
    return @_tallies if @_tallies
    @_tallies = {}
    walk(@node, [@node])
    @_tallies
  end

  def walk(root, scopes)
    root.compact_child_nodes.each do |child|
      next if Hashira::Smells::Scope::FENCES.include?(child.class)
      record(child, scopes)
      walk(child, nested(child, scopes))
    end
  end

  def nested(node, scopes) = SCOPES.include?(node.class) ? scopes + [node] : scopes

  def record(node, scopes)
    return note(SELF, node) if selfish?(node)
    note(holder(node.receiver, scopes), node) if envy?(node)
  end

  def holder(local, scopes) = Local.new(local.name, scopes[-1 - local.depth])

  def selfish?(node)
    SELVES.include?(node.class) || implicit?(node)
  end

  def implicit?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def envy?(node) = local?(node) && @vocabulary.speaks?(node.name)

  def local?(node) = node.is_a?(Prism::CallNode) && LOCALS.include?(node.receiver.class) && node.name != :new

  def note(holder, node) = (@_tallies[holder] ||= []) << node.location.start_line
end
