# frozen_string_literal: true

class Hashira::Coupling::Definitions
  include Enumerable

  def initialize(project, trees, folders = Hashira::Coupling::Folders.new(project.paths))
    @project = project
    @trees = trees
    @folders = folders
  end

  def each(&)
    @trees.each { |file, tree| scan(file, tree, &) }
  end

  def packages = @trees.keys.map { @folders.package(it) }.uniq

  def engine = framework.engine.flat_map { it.split("::") }

  def roots = @_roots ||= autoload.roots

  def implied = autoload.namespaces

  def dependencies = Hashira::Coupling::Dependencies.new(paths.expand("."))

  def spellings = @_spellings ||= Hashira::Coupling::Spellings.new(@trees)

  private

  def paths = @_paths ||= @project.paths

  def framework = @_framework ||= @project.framework

  def autoload = @_autoload ||= Hashira::Coupling::Autoload.new(@project, @trees)

  def path(full, node) = node.is_a?(Prism::ConstantWriteNode) ? full + [node.name.to_s] : full

  def scan(file, tree)
    package = @folders.package(file)
    Hashira::Analysis::TypeWalk.new(tree).walk(roots: roots) do |node, full, stack, lexical|
      next unless lexical == full
      [node, *Hashira::Analysis::Syntax::Body.new(node).constants].each { yield(it, path(full, it), package, stack + [full], file) }
    end
  end
end
