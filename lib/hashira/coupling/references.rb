# frozen_string_literal: true

require "prism"

class Hashira::Coupling::References
  WRITES = [
    Prism::ConstantPathWriteNode, Prism::ConstantPathOrWriteNode,
    Prism::ConstantPathAndWriteNode, Prism::ConstantPathOperatorWriteNode
  ].freeze

  DECLARATIONS = %i[private_constant public_constant include extend prepend].freeze

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
    return collect(node.parent, home) if syntax.dynamic?(node)
    return found << sighting(node, home) if constant?(node)
    return enter(node) if definition?(node)
    spread(node, home + claimed(node))
  end

  def claimed(node)
    target = written(node)
    target ? [syntax.anchor(nesting, syntax.segments(target), @roots)] : []
  end

  def spread(node, scope)
    Hashira::Coupling::Associations.names(node).each { found << named(it, scope) }
    node.compact_child_nodes.each { collect(it, scope) }
  end

  def named(string, scope)
    name = string.unescaped
    rooted = name.start_with?("::")
    [name.delete_prefix("::").split("::"), string.location.start_line, (nesting unless rooted), scope]
  end

  def written(node)
    case node
    when *WRITES then node.target
    when Prism::CallNode then node.receiver if declaration?(node)
    end
  end

  def declaration?(call) = DECLARATIONS.include?(call.name) && syntax.static?(call.receiver)

  def sighting(node, home)
    [syntax.segments(node), node.location.start_line, syntax.rooted?(node) ? nil : nesting, home]
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
