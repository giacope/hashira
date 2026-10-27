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

  def ego = reads(SELF).size

  def lines(holder) = reads(holder).map { it.location.start_line }

  def reads(holder) = tallies.fetch(holder, [])

  def sends(holder) = sent.fetch(holder, [])

  def envious
    peak = tallies.values.map(&:size).max
    holders = tallies.filter_map { |holder, sightings| holder if sightings.size == peak }
    holders.include?(SELF) ? [] : holders
  end

  private

  def tallies = @_tallies ||= tally { @vocabulary.speaks?(it.name) }

  def sent = @_sent ||= tally { !Hashira::Analysis::UNIVERSAL.include?(it.name) }

  def tally
    kept = sightings.select { |holder, node| holder == SELF || yield(node) }
    kept.group_by(&:first).transform_values { it.map(&:last) }
  end

  def sightings = @_sightings ||= walk(@node, [@node])

  def walk(root, scopes)
    root.compact_child_nodes.reject { Hashira::Smells::Scope::FENCES.include?(it.class) }.flat_map do |child|
      [*sighting(child, scopes), *walk(child, nested(child, scopes))]
    end
  end

  def nested(node, scopes) = SCOPES.include?(node.class) ? scopes + [node] : scopes

  def sighting(node, scopes)
    return [[SELF, node]] if selfish?(node)
    local?(node) ? [[holder(node.receiver, scopes), node]] : []
  end

  def holder(local, scopes) = Local.new(local.name, scopes[-1 - local.depth])

  def selfish?(node)
    SELVES.include?(node.class) || implicit?(node)
  end

  def implicit?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def local?(node) = node.is_a?(Prism::CallNode) && LOCALS.include?(node.receiver.class) && node.name != :new
end
