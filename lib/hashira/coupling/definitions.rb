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

  def engine = @project.engine.to_s.split("::")

  def roots = @_roots ||= autoload.roots

  def implied = autoload.namespaces

  def dependencies = @project.dependencies

  private

  def autoload = @_autoload ||= Hashira::Coupling::Autoload.new(@project, @trees)

  def path(full, node) = node.is_a?(Prism::ConstantWriteNode) ? full + [node.name.to_s] : full

  def scan(file, tree)
    package = @project.package(file)
    Hashira::Analysis::TypeWalk.new(tree).walk(roots: roots) do |node, full, stack, lexical|
      next unless lexical == full
      [node, *Hashira::Analysis::Syntax.new(node).constants].each { yield(it, path(full, it), package, stack + [full], file) }
    end
  end
end
