# frozen_string_literal: true

class Hashira::Constraints::Tripwire
  Sighting = Data.define(:file, :line)

  def initialize(trees)
    @trees = trees
  end

  def contradiction = sightings.min_by { [it.file, it.line] }

  private

  attr_reader :trees

  def sightings = trees.flat_map { |file, tree| marks(file, tree) }

  def marks(file, tree) = tripped(tree).map { Sighting.new(file:, line: it.location.start_line) }

  def tripped(tree) = Hashira::Analysis::NodeWalk.collect(tree).select { trips?(it) }

  def bare?(node) = node.is_a?(Prism::CallNode) && !node.receiver

  def named?(node, names) = node.is_a?(Prism::CallNode) && names.include?(node.name)
end
