# frozen_string_literal: true

require "prism"

class Hashira::Smells::Installs
  WRITERS = %i[attr_writer attr_accessor].freeze

  CASTS = %i[to_sym intern].freeze

  INTERPOLATED = [Prism::InterpolatedStringNode, Prism::InterpolatedSymbolNode].freeze

  SET = :instance_variable_set

  SETTERS = [
    Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode,
    Prism::InstanceVariableAndWriteNode, Prism::InstanceVariableOperatorWriteNode,
    Prism::InstanceVariableTargetNode
  ].freeze

  def initialize(type, swept)
    @type = type
    @swept = swept
  end

  def names = @_names ||= writes + attributes

  def writes = surveyed.flat_map { setters(it) }

  def computed = @_computed ||= surveyed.flat_map { |swept| injections(swept).map { prefix(named(it)) } }

  def attributes = macros.flat_map { it.arguments.arguments }.flat_map { words(it) }.map { :"@#{text(it)}" }

  def macros = @swept.grep(Prism::CallNode).select { WRITERS.include?(it.name) && !it.receiver && it.arguments }

  private

  def literal(sets) = sets.map { named(it) }.select { Hashira::Analysis::Syntax.new(it).word? }.map { text(it).to_sym }

  def bodies
    calls = Hashira::Analysis::Syntax.new(@type.node).statements.grep(Prism::CallNode).reject(&:receiver)
    @swept.grep(Prism::DefNode).reject(&:receiver) + calls.filter_map(&:block).grep(Prism::BlockNode)
  end

  def surveyed = @_surveyed ||= bodies.map { Hashira::Smells::Scope.new(it).sweep }

  def setters(swept) = swept.select { SETTERS.include?(it.class) }.map(&:name) + literal(injections(swept))

  def injections(swept) = swept.grep(Prism::CallNode).select { it.name == SET }

  def named(call) = call.arguments&.arguments&.first

  def prefix(name)
    name = name.receiver if name.is_a?(Prism::CallNode) && CASTS.include?(name.name)
    head = name.parts.first if INTERPOLATED.include?(name.class)
    Hashira::Analysis::Syntax.new(head).text if head.is_a?(Prism::StringNode)
  end

  def words(node)
    return [node] if Hashira::Analysis::Syntax.new(node).word?
    node.is_a?(Prism::SplatNode) ? listed(node.expression) : []
  end

  def listed(node)
    value = syntax(declared(syntax(node).segments.last)&.value).thaw
    value.is_a?(Prism::ArrayNode) ? value.elements.select { syntax(it).word? } : []
  end

  def declared(name) = syntax(@type.node).constants.find { it.name.to_s == name }

  def syntax(node) = Hashira::Analysis::Syntax.new(node)

  def text(node) = Hashira::Analysis::Syntax.new(node).text
end
