# frozen_string_literal: true

require "prism"
require_relative "naming"
require_relative "reads"
require_relative "type_tests"

class Hashira::Smells::Foreign
  include Hashira::Smells::Reads

  KEYED_READS = %i[[] fetch values_at dig key?].freeze

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

  def initialize(subject, names, writes)
    @subject = subject
    @names = names
    @writes = writes
  end

  def dismiss?(local)
    name = local.name
    convert? || fenced?(name) || wire?(name) || stock?(name) || derived?(local) || rescued?(name)
  end

  def external?(name) = fenced?(name) || rescued?(name) || writes(name).any? { spawned?(it.value) }

  def kinds(local)
    known(local).flat_map do |path, rooted|
      @names.place(path, @subject.owner, rooted:)
    end.uniq.reject { it == @subject.owner }.map { it.split("::") }
  end

  def guessed?(local) = evidence(local).empty?

  private

  def writes(name) = @writes.of(name)

  def body = @_body ||= Hashira::Smells::Scope.new(@subject.node).inside

  def tails = @_tails ||= Hashira::Analysis::Syntax::Body.new(@subject.node).to_a.compact.last(1)

  def convert? = tails.any? { made?(it) } && stateless?

  def made?(tail)
    tail.is_a?(Prism::CallNode) && tail.name == :new && Hashira::Analysis::Syntax.new(tail.receiver).segments.any?
  end

  def stateless? = body.none? { STATE.include?(it.class) }

  def fenced?(name)
    tested = tests { it == name }
    tested.any? && (tested.none? { |path, rooted| @names.place(path, @subject.owner, rooted:).any? } || indexed?(name))
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
    tested = evidence(local)
    tested.empty? ? Hashira::Smells::Naming.new(local.name).types.map { [it, false] } : tested
  end

  def evidence(local)
    name = local.name
    made = sources(local).grep(Prism::CallNode).map { path(it.receiver) }
    (made + caught(name) + tests { it == name }).reject { |segments, _| segments.empty? }
  end

  def path(node) = Hashira::Analysis::Syntax.new(node).then { [it.segments, it.rooted?] }

  def caught(name)
    snares(name).flat_map { |clause| clause.exceptions.map { path(it) } }
  end

  def yielders(local)
    scope = local.scope
    offered(scope).include?(local.name) ? body.grep(Prism::CallNode).select { it.block == scope } : []
  end

  def offered(block)
    given = block.parameters
    given.is_a?(Prism::BlockParametersNode) ? Hashira::Smells::Parameters.new(given).names : []
  end

  def rescued?(name) = snares(name).any? { alien?(it.exceptions) }

  def keyed?(call) = KEYED_READS.include?(call.name) && keys(call).any? { word?(it) }

  def word?(node) = Hashira::Analysis::Syntax::Word.new(node).word?

  def reassignments(name) = among(Prism::LocalVariableOperatorWriteNode, name)

  def among(kind, name) = body.grep(kind).select { it.name == name }

  def snares(name) = body.grep(Prism::RescueNode).select { it.reference&.name == name }

  def alien?(exceptions)
    exceptions.none? { @names.owns?(it, @subject.owner) }
  end

  def spawned?(value) = value.is_a?(Prism::CallNode) && stranger?(value.receiver)

  def stranger?(node)
    case node
    when Prism::LocalVariableReadNode then fenced?(node.name)
    when Prism::ConstantReadNode, Prism::ConstantPathNode then unowned?(node)
    else node.is_a?(Prism::CallNode) && stranger?(node.receiver)
    end
  end

  def unowned?(node) = !@names.owns?(node, @subject.owner)

  def tests(&) = Hashira::Smells::TypeTests.new(body, @names).of(&)
end
