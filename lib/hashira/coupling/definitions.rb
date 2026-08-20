# frozen_string_literal: true

class Hashira::Coupling::Definitions
  include Enumerable

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def each(&)
    @trees.each { |file, tree| scan(file, tree, &) }
  end

  def packages = @trees.keys.map { @project.package(it) }.uniq

  def roots = @_roots ||= Hashira::Analysis::TypeWalk.roots(@trees)

  private

  def scan(file, tree)
    package = @project.package(file)
    Hashira::Analysis::TypeWalk.each(tree, roots: roots) do |node, full|
      yield(node, full, package)
      Hashira::Analysis::Syntax.constants(node).each { yield(it, full + [it.name.to_s], package) }
    end
  end
end
