# frozen_string_literal: true

module Hashira::Engine
  PARENTS = %w[Rails::Engine ::Rails::Engine].freeze

  MARK = /<\s*(?:::)?Rails::Engine\b|^\s*isolate_namespace\b/

  SCANNED = 5_000

  module_function

  def namespaces(directories, home)
    scanned(directories, home).select { File.binread(it).match?(MARK) }.filter_map { namespace(it) }.uniq
  end

  def scanned(directories, home) = (shipped(directories) + Dir[File.join(home, "lib/**/*.rb")]).uniq.first(SCANNED)

  def shipped(directories) = directories.flat_map { Dir["#{it}/**/*.rb"] }.select { "/#{it}".include?("/lib/") }

  def namespace(file)
    found = []
    Hashira::Analysis::TypeWalk.each(Hashira::Trees.parse(file)) do |node, full|
      found.concat(isolated(node))
      found << full[0...-1] if engine?(node)
    end
    found.first&.join("::")
  end

  def engine?(node) = node.is_a?(Prism::ClassNode) && PARENTS.include?(node.superclass&.slice)

  def isolated(node)
    Hashira::Analysis::Syntax.statements(node).grep(Prism::CallNode).select { it.name == :isolate_namespace && it.arguments }
      .map { Hashira::Analysis::Syntax.segments(it.arguments.arguments.first) }.reject(&:empty?)
  end
end
