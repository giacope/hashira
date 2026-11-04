# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Kin
  MIXINS = %i[include prepend].freeze

  def initialize(node, scope)
    @node = node
    @scope = scope
  end

  def to_a = form.type? ? [*ancestors(parent, @scope[...-1]), *ancestors(mixins, @scope)] : []

  def parent = form.klass? ? [@node.superclass].compact : []

  def claimed?(claims)
    opening = @scope.last
    return false if form.type? && opening.one? && claims.core?(opening.first)
    created? || claims.held?(opening)
  end

  def opened = defining? ? [@scope.last] : []

  private

  def form = Hashira::Coupling::Form.new(@node)

  def created? = @node.is_a?(Prism::ConstantWriteNode) || !parent.empty?

  def defining? = created? || form.to_a.any? { !autoload?(it) }

  def autoload?(statement) = statement.is_a?(Prism::CallNode) && statement.name == :autoload

  def mixins
    calls = form.to_a.grep(Prism::CallNode).select { MIXINS.include?(it.name) && !it.receiver && it.arguments }
    calls.flat_map { it.arguments.arguments }
  end

  def ancestors(nodes, nesting)
    nodes.map { Hashira::Analysis::Syntax.new(it) }.select(&:static?).map do |read|
      Hashira::Coupling::Ancestor.new(read.segments, read.rooted? ? [] : nesting)
    end
  end
end
