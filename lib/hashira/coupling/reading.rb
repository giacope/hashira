# frozen_string_literal: true

class Hashira::Coupling::Reading
  def self.build(project, trees, definitions)
    framework = project.framework
    new(trees, project.paths, definitions, Hashira::Coupling::Associations.new(framework.inflection))
  end

  def initialize(trees, paths, definitions, associations)
    @trees = trees
    @paths = paths
    @definitions = definitions
    @associations = associations
  end

  def each
    @trees.each do |file, tree|
      yield(@paths.relative(file), file, tree, Hashira::Coupling::References.new(@definitions.roots, @associations))
    end
  end

  def to_h = @trees
end
