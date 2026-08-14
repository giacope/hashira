# frozen_string_literal: true

require "prism"

class Hashira::Smells::Foreign
  TYPE_TESTS = %i[is_a? kind_of? instance_of?].freeze

  KEYED_READS = %i[[] fetch values_at dig key?].freeze

  KEYS = [Prism::StringNode, Prism::SymbolNode].freeze

  LITERALS = [Prism::HashNode, Prism::KeywordHashNode, Prism::ArrayNode, Prism::StringNode].freeze

  STATE = [
    Prism::InstanceVariableReadNode, Prism::InstanceVariableWriteNode,
    Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
    Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(subject, ownership)
    @subject = subject
    @ownership = ownership
  end

  def dismiss?(name)
    convert? || fenced?(name) || wire?(name) || built?(name) ||
      derived?(name) || rescued?(name)
  end

  def reaches
    tests { true }.reject { @ownership.owned?(it) }.map(&:first).uniq
  end

  private

  def body = @body ||= Hashira::Smells::Scope.inside(@subject.node)

  def tail = @tail ||= Hashira::Analysis::Syntax.statements(@subject.node).compact.last

  def convert?
    tail.is_a?(Prism::CallNode) && tail.name == :new &&
      Hashira::Analysis::Syntax.segments(tail.receiver).any? && stateless?
  end

  def stateless? = body.none? { STATE.include?(it.class) }

  def fenced?(name)
    tested = tests { it == name }
    tested.any? && tested.none? { @ownership.owned?(it) }
  end

  def wire?(name)
    calls = body.grep(Prism::CallNode).select { |call| local?(call.receiver) { it == name } }
    calls.any? && calls.all? { keyed?(it) } && reassignments(name).none?
  end

  def built?(name)
    writes(name).any? { LITERALS.include?(it.value.class) }
  end

  def derived?(name)
    writes(name).any? { spawned?(it.value) }
  end

  def rescued?(name)
    snares(name).any? { alien?(it.exceptions) }
  end

  def keyed?(call)
    names = call.arguments&.arguments
    KEYED_READS.include?(call.name) && names&.any? &&
      names.all? { KEYS.include?(it.class) }
  end

  def writes(name) = among(Prism::LocalVariableWriteNode, name)

  def reassignments(name) = among(Prism::LocalVariableOperatorWriteNode, name)

  def among(kind, name)
    body.grep(kind).select { it.name == name }
  end

  def snares(name)
    body.grep(Prism::RescueNode).select { it.reference&.name == name }
  end

  def alien?(exceptions)
    exceptions.map { Hashira::Analysis::Syntax.segments(it) }.none? { @ownership.owned?(it) }
  end

  def spawned?(value)
    value.is_a?(Prism::CallNode) && stranger?(value.receiver)
  end

  def stranger?(node)
    case node
    when Prism::LocalVariableReadNode then fenced?(node.name)
    when Prism::ConstantReadNode, Prism::ConstantPathNode then unowned?(node)
    else false
    end
  end

  def unowned?(node)
    !@ownership.owned?(Hashira::Analysis::Syntax.segments(node))
  end

  def tests(&)
    (probes(&) + arms(&)).map { Hashira::Analysis::Syntax.segments(it) }.reject(&:empty?) + lookups(&)
  end

  def probes(&)
    body.grep(Prism::CallNode).select { TYPE_TESTS.include?(it.name) && local?(it.receiver, &) }.filter_map { key(it) }
  end

  def arms(&)
    body.grep(Prism::CaseNode).select { local?(it.predicate, &) }.flat_map(&:conditions).flat_map(&:conditions)
  end

  def lookups(&)
    body.grep(Prism::CallNode).select { it.name == :[] && sorts?(key(it), &) }.flat_map { @ownership.keys(Hashira::Analysis::Syntax.segments(it.receiver)) }
  end

  def sorts?(argument, &)
    argument.is_a?(Prism::CallNode) && argument.name == :class &&
      local?(argument.receiver, &)
  end

  def local?(node, &) = node.is_a?(Prism::LocalVariableReadNode) && yield(node.name)

  def key(call) = call.arguments&.arguments&.first
end
