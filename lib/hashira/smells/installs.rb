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

  def computed = @_computed ||= surveyed.flat_map { |swept| injections(swept).flat_map { prefixes(it) } }

  def writes = surveyed.flat_map { setters(it) }

  def attributes
    macros = @swept.grep(Prism::CallNode).select { WRITERS.include?(it.name) && !it.receiver && it.arguments }
    macros.flat_map { it.arguments.arguments }.flat_map { words(it) }.map { :"@#{text(it)}" }
  end

  private

  def literal(sets) = sets.flat_map { named(it) }.select { word?(it) }.map { text(it).to_sym }

  def bodies
    calls = Hashira::Analysis::Syntax::Body.new(@type.node).to_a.grep(Prism::CallNode).reject(&:receiver)
    @swept.grep(Prism::DefNode).reject(&:receiver) + calls.filter_map(&:block).grep(Prism::BlockNode)
  end

  def surveyed = @_surveyed ||= bodies.map { Hashira::Smells::Scope.new(it).sweep }

  def setters(swept) = swept.select { SETTERS.include?(it.class) }.map(&:name) + literal(injections(swept))

  def injections(swept) = swept.grep(Prism::CallNode).select { it.name == SET }

  def named(call) = Array(call.arguments&.arguments).first(1)

  def prefixes(call)
    named(call).flat_map do |name|
      name = name.receiver if name.is_a?(Prism::CallNode) && CASTS.include?(name.name)
      heads = INTERPOLATED.include?(name.class) ? name.parts.first(1) : []
      heads.grep(Prism::StringNode).map { text(it) }
    end
  end

  def words(node)
    return [node] if word?(node)
    node.is_a?(Prism::SplatNode) ? listed(node.expression) : []
  end

  def listed(node)
    declared(node).flat_map do |constant|
      value = Hashira::Analysis::Syntax::Value.new(constant.value).thaw
      value.is_a?(Prism::ArrayNode) ? value.elements.select { word?(it) } : []
    end
  end

  def declared(node)
    name = Hashira::Analysis::Syntax.new(node).segments.last
    Hashira::Analysis::Syntax::Body.new(@type.node).constants.select { it.name.to_s == name }.first(1)
  end

  def text(node) = Hashira::Analysis::Syntax::Word.new(node).to_s

  def word?(node) = Hashira::Analysis::Syntax::Word.new(node).word?
end
