# frozen_string_literal: true

class Hashira::Coupling::Definitions
  include Enumerable

  def self.build(project, trees)
    new(trees, Hashira::Coupling::Folders.new(project.paths), Hashira::Coupling::Autoload.new(project, trees))
  end

  def initialize(trees, folders, autoload)
    @trees = trees
    @folders = folders
    @autoload = autoload
  end

  def each(&)
    @trees.each { |file, tree| scan(file, tree, &) }
  end

  def packages = @trees.keys.map { @folders.package(it) }.uniq

  def roots = @_roots ||= @autoload.roots

  def implied = @autoload.namespaces

  private

  def path(full, node) = node.is_a?(Prism::ConstantWriteNode) ? full + [node.name.to_s] : full

  def scan(file, tree)
    Hashira::Analysis::TypeWalk.new(tree).walk(roots: roots) do |node, full, stack, lexical|
      next unless lexical == full
      [node, *Hashira::Analysis::Syntax::Body.new(node).constants].each { yield(it, path(full, it), stack + [full], file) }
    end
  end
end
