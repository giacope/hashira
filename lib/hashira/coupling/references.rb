# frozen_string_literal: true

require "prism"

class Hashira::Coupling::References
  def initialize(roots = nil)
    @roots = roots
  end

  def list(tree) = sightings(tree).map(&:first)

  def sightings(tree)
    collect(tree)
    found
  end

  private

  def found = @_found ||= []

  def scopes = @_scopes ||= [[]]

  def nesting = scopes.last

  def collect(node, home = nesting)
    return unless node
    return found << sighting(node, home) if constant?(node)
    return enter(node) if definition?(node)
    node.compact_child_nodes.each { collect(it, home) }
  end

  def sighting(node, home)
    [syntax.segments(node), node.location.start_line, syntax.cbase?(node) ? nil : nesting, home]
  end

  def syntax = Hashira::Analysis::Syntax

  def constant?(node) = node.is_a?(Prism::ConstantPathNode) || node.is_a?(Prism::ConstantReadNode)

  def definition?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

  def enter(node)
    opened = nesting + [anchor(node)]
    collect(node.superclass, opened) if node.is_a?(Prism::ClassNode)
    inside(opened) { collect(node.body) }
  end

  def anchor(node) = syntax.anchor(nesting, syntax.segments(node.constant_path), @roots)

  def inside(scope)
    scopes << scope
    yield
    scopes.pop
  end
end
