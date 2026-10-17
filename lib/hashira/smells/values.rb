# frozen_string_literal: true

require "prism"

class Hashira::Smells::Values
  FACTORIES = { "Struct" => :new, "Data" => :define }.freeze

  def initialize(trees)
    @trees = trees
  end

  def include?(name) = names.include?(name)

  private

  def names
    @_names ||=
      Set.new.tap do |found|
        @trees.each do |tree|
          Hashira::Analysis::TypeWalk.each(tree) { |node, full| harvest(node, full, found) }
        end
      end
  end

  def harvest(node, full, found)
    found.merge(Hashira::Analysis::Syntax.constants(node).select { factory?(it.value) }.map { it.name.to_s })
    found << full.last if node.is_a?(Prism::ClassNode) && factory?(node.superclass)
  end

  def factory?(value) = Hashira::Smells::Factory.made?(value, FACTORIES)
end
