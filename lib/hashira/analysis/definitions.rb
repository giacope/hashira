# frozen_string_literal: true

class Hashira::Analysis::Definitions
  include Enumerable

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def each(&)
    @trees.each { |file, tree| scan(file, tree, &) }
  end

  def packages = @trees.keys.map { @project.package(it) }.uniq

  def roots
    @roots ||= @trees.each_value.with_object(Set.new) { |tree, set| survey(tree, set) }
  end

  private

  def survey(tree, set)
    Hashira::Analysis::TypeWalk.each(tree) { |_node, full| set << full }
  end

  def scan(file, tree)
    package = @project.package(file)
    Hashira::Analysis::TypeWalk.each(tree, roots: roots) { |node, full| yield(node, full, package) }
  end
end
