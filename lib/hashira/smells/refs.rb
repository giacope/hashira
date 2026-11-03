# frozen_string_literal: true

require "prism"

class Hashira::Smells::Refs
  class Local
    def initialize(name, scope)
      @name = name
      @scope = scope
    end

    def ==(other) = other.is_a?(self.class) && key == other.key

    def eql?(other) = self == other

    def hash = key.hash

    def to_sym = @name

    def beside?(other) = @scope.is_a?(Prism::BlockNode) && @scope.equal?(other.scope)

    def yielders(nodes) = bound? ? nodes.grep(Prism::CallNode).select { it.block.equal?(@scope) } : []

    protected

    attr_reader :scope

    def key = [@name, @scope]

    private

    def bound?
      given = @scope&.parameters
      given.is_a?(Prism::BlockParametersNode) && Hashira::Smells::Parameters.new(given).names.include?(@name)
    end
  end

  SELF = Local.new(:self, nil)

  LOCALS = [Prism::LocalVariableReadNode, Prism::LocalVariableWriteNode].freeze

  SELVES = [
    Prism::SelfNode, Prism::SuperNode, Prism::ForwardingSuperNode,
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(definition, words, messages = Hashira::Runtime::Messages.new)
    @node = definition
    @words = words
    @messages = messages
  end

  def lines(holder = SELF) = reads(holder).map { it.location.start_line }

  def reads(holder) = tallies.fetch(holder, [])

  def sends(holder) = sent.fetch(holder, [])

  def envious
    peak = tallies.values.map(&:size).max
    holders = tallies.filter_map { |holder, sightings| holder if sightings.size == peak }
    holders.include?(SELF) ? [] : holders
  end

  private

  def tallies = @_tallies ||= tally { @words.speaks?(it.name) }

  def sent = @_sent ||= tally { !@messages.universal?(it.name) }

  def tally
    kept = sightings.select { |holder, node| holder == SELF || yield(node) }
    kept.group_by(&:first).transform_values { it.map(&:last) }
  end

  def sightings = @_sightings ||= walk(@node, [@node])

  def walk(root, scopes)
    root.compact_child_nodes.reject { Hashira::Smells::Border.new(it).fence? }.flat_map do |child|
      [*sighting(child, scopes), *walk(child, nested(child, scopes))]
    end
  end

  def nested(node, scopes) = Hashira::Smells::Border.new(node).closure? ? scopes + [node] : scopes

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
