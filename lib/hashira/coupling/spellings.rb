# frozen_string_literal: true

require "prism"

class Hashira::Coupling::Spellings
  REQUIRE = %i[require].freeze

  REQUIRED = %r{\A([a-z][a-z0-9_]*)(?:/|\z)}

  LOWER = /[a-z]/

  def initialize(trees)
    @trees = trees
  end

  def required = @_required ||= (nodes.filter_map { root(it) }.to_set - shipped).to_set { camel(it) }

  def twin?(root, opened)
    read.any? { it != root && it.match?(LOWER) && fold(it) == fold(root) && !opened.include?(it) }
  end

  private

  def read = @_read ||= nodes.grep(Prism::ConstantReadNode).to_set { it.name.to_s }

  def nodes = @trees.values.flat_map { Hashira::Analysis::NodeWalk.new(it).collect }

  def root(node)
    return unless Hashira::Analysis::Syntax.new(node).macro?(REQUIRE)
    Hashira::Analysis::Syntax.new(node.arguments.arguments.first).literal.to_s[REQUIRED, 1]
  end

  def shipped = @trees.keys.flat_map { it.delete_suffix(".rb").split("/") }

  def camel(name) = name.split("_").map(&:capitalize).join

  def fold(name) = name.downcase.delete("_")
end
