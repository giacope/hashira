# frozen_string_literal: true

require "prism"
require_relative "naming"
require_relative "reads"
require_relative "type_tests"

class Hashira::Smells::Foreign
  include Hashira::Smells::Reads

  TYPE_TESTS = Hashira::Smells::TypeTests::CHECKS

  KEYED_READS = %i[[] fetch values_at dig key?].freeze

  KEYS = [Prism::StringNode, Prism::SymbolNode].freeze

  LITERALS = [Prism::HashNode, Prism::KeywordHashNode, Prism::ArrayNode, Prism::StringNode].freeze

  STOCK = [
    *LITERALS, Prism::InterpolatedStringNode, Prism::SymbolNode, Prism::IntegerNode, Prism::FloatNode,
    Prism::ConstantReadNode, Prism::ConstantPathNode
  ].freeze

  SHAPES = %i[permit to_h to_a map flat_map filter_map].freeze

  STATE = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(subject, ownership)
    @subject = subject
    @ownership = ownership
  end

  def dismiss?(local)
    name = local.name
    convert? || fenced?(name) || wire?(name) || stock?(name) || derived?(local) || rescued?(name)
  end

  def reaches
    tests { true }.reject { @ownership.owned?(it, @subject.owner) }.map(&:first).uniq
  end

  def entering?(node)
    return inbound?(node) unless node.is_a?(Prism::LocalVariableReadNode)
    sources = writes(node.name)
    sources.any? && sources.all? { inbound?(it.value) }
  end

  def external?(name) = fenced?(name) || rescued?(name) || writes(name).any? { spawned?(it.value) }

  def kinds(local)
    known(local).filter_map do
      @ownership.place(it, @subject.owner)
    end.uniq.reject { it == @subject.owner }.map { it.split("::") }
  end

  def built?(name) = writes(name).any? { LITERALS.include?(it.value.class) }

  def writes(name) = among(Prism::LocalVariableWriteNode, name)

  private

  def body = @_body ||= Hashira::Smells::Scope.inside(@subject.node)

  def tail = @_tail ||= Hashira::Analysis::Syntax.statements(@subject.node).compact.last

  def convert?
    tail.is_a?(Prism::CallNode) && tail.name == :new &&
      Hashira::Analysis::Syntax.segments(tail.receiver).any? && stateless?
  end

  def stateless? = body.none? { STATE.include?(it.class) }

  def fenced?(name)
    tested = tests { it == name }
    tested.any? && (tested.none? { @ownership.owned?(it, @subject.owner) } || indexed?(name))
  end

  def indexed?(name) = body.grep(Prism::CallNode).any? { local?(it.receiver) { it == name } && keyed?(it) }

  def wire?(name)
    calls = body.grep(Prism::CallNode).select { |call| local?(call.receiver) { it == name } }
    calls.any? && calls.all? { keyed?(it) } && reassignments(name).none?
  end

  def stock?(name) = writes(name).any? { staple?(it.value) }

  def staple?(value) = STOCK.include?(value.class) || (value.is_a?(Prism::CallNode) && SHAPES.include?(value.name))

  def derived?(local) = sources(local).any? { spawned?(it) }

  def sources(local) = writes(local.name).map(&:value) + yielders(local)

  def known(local)
    name = local.name
    tested = (sources(local).map { made(it) } + caught(name) + tests { it == name }).reject(&:empty?)
    tested.empty? ? Hashira::Smells::Naming.types(name) : tested
  end

  def made(value) = value.is_a?(Prism::CallNode) ? Hashira::Analysis::Syntax.segments(value.receiver) : []

  def caught(name) = snares(name).flat_map { |clause| clause.exceptions.map { Hashira::Analysis::Syntax.segments(it) } }

  def yielders(local)
    scope = local.scope
    offered(scope).include?(local.name) ? body.grep(Prism::CallNode).select { it.block == scope } : []
  end

  def offered(block)
    given = block.parameters
    given.is_a?(Prism::BlockParametersNode) ? Hashira::Smells::Parameters.names(given) : []
  end

  def rescued?(name) = snares(name).any? { alien?(it.exceptions) }

  def inbound?(node) = node.is_a?(Prism::CallNode) && (fetched?(node) || spawned?(node))

  def fetched?(call) = keyed?(call) && !local?(call.receiver) { built?(it) }

  def keyed?(call) = KEYED_READS.include?(call.name) && KEYS.include?(key(call).class)

  def reassignments(name) = among(Prism::LocalVariableOperatorWriteNode, name)

  def among(kind, name) = body.grep(kind).select { it.name == name }

  def snares(name) = body.grep(Prism::RescueNode).select { it.reference&.name == name }

  def alien?(exceptions)
    exceptions.none? { @ownership.owns?(it, @subject.owner) }
  end

  def spawned?(value) = value.is_a?(Prism::CallNode) && stranger?(value.receiver)

  def stranger?(node)
    case node
    when Prism::LocalVariableReadNode then fenced?(node.name)
    when Prism::ConstantReadNode, Prism::ConstantPathNode then unowned?(node)
    else node.is_a?(Prism::CallNode) && stranger?(node.receiver)
    end
  end

  def unowned?(node) = !@ownership.owns?(node, @subject.owner)

  def tests(&) = checks.of(&)

  def checks = @_checks ||= Hashira::Smells::TypeTests.new(body, @ownership)
end
