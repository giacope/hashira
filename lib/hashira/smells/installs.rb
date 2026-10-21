# frozen_string_literal: true

require "prism"

class Hashira::Smells::Installs
  WRITERS = %i[attr_writer attr_accessor].freeze

  CASTS = %i[to_sym intern].freeze

  INTERPOLATED = [Prism::InterpolatedStringNode, Prism::InterpolatedSymbolNode].freeze

  SETTERS = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(type, swept)
    @type = type
    @swept = swept
  end

  def names = writes + attributes

  def writes = bodies.flat_map { setters(it) }

  def attributes = macros.flat_map { it.arguments.arguments }.flat_map { words(it) }.map { :"@#{text(it)}" }

  def macros = @swept.grep(Prism::CallNode).select { WRITERS.include?(it.name) && !it.receiver && it.arguments }

  private

  def bodies
    calls = Hashira::Analysis::Syntax.statements(@type.node).grep(Prism::CallNode).reject(&:receiver)
    @swept.grep(Prism::DefNode).reject(&:receiver) + calls.filter_map(&:block).grep(Prism::BlockNode)
  end

  def setters(node)
    swept = Hashira::Smells::Scope.sweep(node)
    swept.select { SETTERS.include?(it.class) }.map(&:name) + swept.filter_map { injected(it) }
  end

  def injected(node)
    return unless node.is_a?(Prism::CallNode) && node.name == :instance_variable_set
    first = node.arguments&.arguments&.first
    Hashira::Analysis::Syntax.word?(first) ? Hashira::Analysis::Syntax.symbol(first) : prefix(first)
  end

  def prefix(name)
    name = name.receiver if name.is_a?(Prism::CallNode) && CASTS.include?(name.name)
    head = name.parts.first if INTERPOLATED.include?(name.class)
    Hashira::Analysis::Syntax.text(head) if head.is_a?(Prism::StringNode)
  end

  def words(node)
    return [node] if Hashira::Analysis::Syntax.word?(node)
    node.is_a?(Prism::SplatNode) ? listed(node.expression) : []
  end

  def listed(node)
    name = Hashira::Analysis::Syntax.segments(node).last
    found = Hashira::Analysis::Syntax.constants(@type.node).find { it.name.to_s == name }
    value = Hashira::Analysis::Syntax.thaw(found&.value)
    value.is_a?(Prism::ArrayNode) ? value.elements.select { Hashira::Analysis::Syntax.word?(it) } : []
  end

  def text(node) = Hashira::Analysis::Syntax.text(node)
end
