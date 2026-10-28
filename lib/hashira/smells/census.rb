# frozen_string_literal: true

require "prism"

class Hashira::Smells::Census
  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def ownership = @_ownership ||= Hashira::Smells::Ownership.new(@trees.values, catalog)

  def catalog = @_catalog ||= Hashira::Coupling::Catalog.new(Hashira::Coupling::Definitions.new(@project, @trees))

  def types = @_types ||= settled(Hashira::Smells::Concerns.new(sketches).settled)

  def sketches
    found = @trees.flat_map { |path, tree| harvest(@project.relative(path), tree) }
    opened, defined = found.partition { it.node.is_a?(Prism::BlockNode) }
    kinds = defined.to_h { [it.name, it.kind] }
    defined + opened.map { it.with(kind: kinds.fetch(it.name, it.kind)) }
  end

  private

  def settled(found)
    lineage = Hashira::Smells::Lineage.new(found, found.reject { claimed?(it) }.to_set(&:name))
    kinship = Hashira::Smells::Kinship.new(found, lineage)
    found.map { lineage.settle(it, protocol: kinship.protocol(it), ownership:, claimed: claimed?(it)) }
  end

  def roots = @_roots ||= Hashira::Coupling::Autoload.new(@project, @trees).roots

  def harvest(file, tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk(roots:) do |node, full, _stack, lexical|
      kind = node.is_a?(Prism::ClassNode) ? :class : :module
      found << Hashira::Smells::Sketch.new(full.join("::"), node, kind, file, lexical)
    end
    found
  end

  def claimed?(sketch) = catalog.claimed?(sketch.lexical)
end
