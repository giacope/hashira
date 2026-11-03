# frozen_string_literal: true

class Hashira::Smells::Census
  def initialize(
    project, trees,
    catalog = Hashira::Coupling::Catalog.build(project, trees, Hashira::Coupling::Definitions.build(project, trees)),
    kit = Hashira::Smells::Kit.new(trees.values, catalog)
  )
    @project = project
    @trees = trees
    @catalog = catalog
    @kit = kit
  end

  def types = @_types ||= settled(Hashira::Smells::Sketches.new(harvested, catalog).to_a)

  def report(boundaries, rules) = @kit.report(types, boundaries, rules)

  private

  attr_reader :catalog

  def harvested
    paths = @project.paths
    @trees.flat_map do |path, tree|
      file = paths.relative(path)
      walk = Hashira::Analysis::TypeWalk.new(tree).to_enum(:walk, roots:)
      walk.map { |node, full, _stack, lexical| [full.join("::"), node, file, lexical] }
    end
  end

  def settled(found)
    typeset = Hashira::Smells::Typeset.new(found)
    lineage = Hashira::Smells::Lineage.new(found, typeset)
    kinship = Hashira::Smells::Kinship.new(found, typeset)
    found.map { lineage.settle(it, kinship.protocol(it)) }
  end

  def roots = @_roots ||= Hashira::Coupling::Autoload.new(@project, @trees).roots
end
