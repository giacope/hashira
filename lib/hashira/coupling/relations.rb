# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Relations
  MIXINS = %i[include prepend].freeze

  def initialize(node, nesting, path)
    @node = node
    @nesting = nesting
    @path = path
  end

  def to_a = supers + included

  def included = mixins.map { [it, @nesting] }

  def assignments = body.constants.map { [@path + [it.name.to_s], it.value, @nesting] }

  def loads? = body.to_a.grep(Prism::CallNode).any? { outward?(it.receiver) }

  private

  def body = Hashira::Analysis::Syntax::Body.new(@node)

  def supers = @node.is_a?(Prism::ClassNode) && @node.superclass ? [[@node.superclass, @nesting[...-1]]] : []

  def mixins = MIXINS.flat_map { body.calls(it) }.flat_map { it.arguments.arguments }

  def outward?(receiver)
    receiver.is_a?(Prism::CallNode) ? outward?(receiver.receiver) : Hashira::Analysis::Syntax.new(receiver).static?
  end
end
