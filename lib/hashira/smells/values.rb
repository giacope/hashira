# frozen_string_literal: true

require "prism"

class Hashira::Smells::Values
  FACTORIES = { "Struct" => :new, "Data" => :define }.freeze

  def initialize(trees)
    @trees = trees
  end

  def include?(name) = names.include?(name)

  private

  def names = @_names ||= @trees.flat_map { |tree| harvested(tree) }.to_set

  def harvested(tree)
    Hashira::Analysis::TypeWalk.new(tree).to_enum(:walk).flat_map { |node, full| harvest(node, full) }
  end

  def harvest(node, full)
    made = Hashira::Analysis::Syntax.new(node).constants.select { factory?(it.value) }.map { it.name.to_s }
    node.is_a?(Prism::ClassNode) && factory?(node.superclass) ? made + [full.last] : made
  end

  def factory?(value) = Hashira::Smells::Factory.new(value).made?(FACTORIES)
end
