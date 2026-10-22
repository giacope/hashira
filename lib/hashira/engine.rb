# frozen_string_literal: true

class Hashira::Engine
  PARENTS = Hashira::Coupling::Definition::ENGINES

  MARK = /<\s*(?:::)?Rails::Engine\b|^\s*isolate_namespace\b/

  SCANNED = 5_000

  def initialize(directories, home)
    @directories = directories
    @home = home
  end

  def namespaces
    shipped = @directories.flat_map { Dir["#{it}/**/*.rb"] }.select { "/#{it}".include?("/lib/") }
    scanned = (shipped + Dir[File.join(@home, "lib/**/*.rb")]).uniq.first(SCANNED)
    scanned.select { File.binread(it).match?(MARK) }.filter_map { namespace(it) }.uniq
  end

  private

  def namespace(file)
    found = []
    Hashira::Analysis::TypeWalk.new(Hashira::Trees.parse(file)).walk do |node, full|
      found.concat(isolated(node))
      found << full[0...-1] if engine?(node)
    end
    found.first&.join("::")
  end

  def engine?(node) = node.is_a?(Prism::ClassNode) && PARENTS.include?(node.superclass&.slice)

  def isolated(node)
    Hashira::Analysis::Syntax.new(node).statements.grep(Prism::CallNode).select { it.name == :isolate_namespace && it.arguments }
      .map { Hashira::Analysis::Syntax.new(it.arguments.arguments.first).segments }.reject(&:empty?)
  end
end
