# frozen_string_literal: true

require "prism"

class Hashira::Coupling::References
  WRITES = [
    Prism::ConstantPathWriteNode, Prism::ConstantPathOrWriteNode,
    Prism::ConstantPathAndWriteNode, Prism::ConstantPathOperatorWriteNode
  ].freeze

  DECLARATIONS = %i[private_constant public_constant include extend prepend].freeze

  def initialize(roots = nil, associations = Hashira::Coupling::Associations::NONE)
    @roots = roots
    @associations = associations
  end

  def list(tree) = sightings(tree).map(&:first)

  def sightings(tree)
    collect(tree)
    found
  end

  def guarantees = @_guarantees.to_h

  private

  def found = @_found ||= []

  def scopes = @_scopes ||= [[]]

  def nesting = scopes.last

  def collect(node, home = nesting)
    return unless node
    return collect(node.parent, home) if syntax(node).dynamic?
    return found << sighting(node, home) if constant?(node)
    return enter(node) if definition?(node)
    spread(node, home + claimed(node))
  end

  def claimed(node)
    target = written(node)
    target ? [syntax(target).place(nesting, @roots)] : []
  end

  def spread(node, scope)
    @associations.targets(node).each { found << named(it, scope) }
    node.compact_child_nodes.each { collect(it, scope) }
  end

  def named(target, scope)
    name, line, guarantee, macro = target.deconstruct
    segments = name.delete_prefix("::").split("::")
    (@_guarantees ||= {})["#{line}: #{segments.join("::")}"] = "#{line}: #{guarantee}" if guarantee
    [segments, line, (nesting unless name.start_with?("::")), scope, macro]
  end

  def written(node)
    case node
    when *WRITES then node.target
    when Prism::CallNode then node.receiver if declaration?(node)
    end
  end

  def declaration?(call) = DECLARATIONS.include?(call.name) && syntax(call.receiver).static?

  def sighting(node, home)
    read = syntax(node)
    [read.segments, node.location.start_line, read.rooted? ? nil : nesting, home]
  end

  def syntax(node) = Hashira::Analysis::Syntax.new(node)

  def constant?(node) = node.is_a?(Prism::ConstantPathNode) || node.is_a?(Prism::ConstantReadNode)

  def definition?(node) = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)

  def enter(node)
    opened = nesting + [anchor(node)]
    collect(node.superclass, opened) if node.is_a?(Prism::ClassNode)
    inside(opened) { collect(node.body) }
  end

  def anchor(node) = syntax(node.constant_path).place(nesting, @roots)

  def inside(scope)
    scopes << scope
    yield
    scopes.pop
  end
end
