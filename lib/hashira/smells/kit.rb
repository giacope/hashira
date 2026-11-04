# frozen_string_literal: true

class Hashira::Smells::Kit
  def initialize(
    trees, catalog, walk = Hashira::Smells::Walk.new(trees), ownership = Hashira::Smells::Ownership.new(walk, catalog)
  )
    @trees = trees
    @catalog = catalog
    @walk = walk
    @ownership = ownership
  end

  def report(types, boundaries, rules, family = Hashira::Smells::Hierarchy.new(types))
    constants = Hashira::Smells::Constants.new(@walk, @catalog)
    names = Hashira::Smells::Names.new(@ownership, constants)
    reaches = Hashira::Smells::Reaches.build(@trees, @ownership, names)
    probing = Hashira::Smells::Probing.build(@trees, @walk, @ownership, names)
    Hashira::Smells::Report.new(types, rules, probing, Hashira::Smells::Judging.new(family, names, reaches, boundaries))
  end
end
