# frozen_string_literal: true

require "prism"

class Hashira::Smells::Census
  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def ownership = @_ownership ||= Hashira::Smells::Ownership.new(@trees.values, catalog)

  def catalog = @_catalog ||= Hashira::Coupling::Catalog.new(Hashira::Coupling::Definitions.new(@project, @trees))

  def types = @_types ||= placed(@trees.flat_map { |path, tree| harvest(@project.relative(path), tree) })

  private

  def placed(found) = settled(found, Hashira::Smells::Lineage.new(found))

  def settled(found, lineage)
    kinship = Hashira::Smells::Kinship.new(found, lineage)
    found.map { lineage.settle(it, protocol: kinship.protocol(it), ownership:, claimed: claimed?(it)) }
  end

  def roots = @_roots ||= Hashira::Coupling::Autoload.new(@project, @trees).roots

  def harvest(file, tree)
    found = []
    Hashira::Analysis::TypeWalk.new(tree).walk(roots:) { |node, full| found << Hashira::Smells::Sketch.new(full.join("::"), node, kind(node), file) }
    found
  end

  def kind(node) = node.is_a?(Prism::ModuleNode) ? :module : :class

  def claimed?(sketch) = catalog.claimed?(sketch.name.split("::"))
end
