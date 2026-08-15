# frozen_string_literal: true

require "prism"

class Hashira::Smells::Census
  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def ownership = @_ownership ||= Hashira::Smells::Ownership.new(@trees.values)

  def types = @trees.flat_map { |path, tree| harvest(@project.relative(path), tree) }

  private

  def harvest(file, tree)
    found = []
    Hashira::Analysis::TypeWalk.each(tree) { |node, full| found << context(file, node, full.join("::")) }
    found
  end

  def context(file, node, name)
    Hashira::Smells::TypeContext.new(name:, node:, kind: kind(node), file:, defs: defs(name, node, file))
  end

  def kind(node) = node.is_a?(Prism::ModuleNode) ? :module : :class

  def defs(name, node, file)
    Hashira::Smells::Visibility.new(node).entries.map do |definition, section|
      Hashira::Smells::MethodContext.new(owner: name, node: definition, file:, section:, ownership:)
    end
  end
end
