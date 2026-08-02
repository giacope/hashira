# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Harvest
  WHOLE = [Prism::DefNode, Prism::WhenNode, Prism::RescueNode].freeze

  def initialize(project, trees)
    @project = project
    @fragments = trees.flat_map { |path, tree| scan(@project.relative(path), tree) }
  end

  attr_reader :fragments

  private

  def scan(rel, tree)
    nodes = Hashira::Analysis::NodeWalk.collect(tree)
    windows(rel, nodes) + wholes(nodes).map { Hashira::Duplication::Fragment.new(rel, [it]) }
  end

  def windows(rel, nodes) = runs(nodes).flat_map { Hashira::Duplication::Sequence.new(rel, it).fragments }

  def runs(nodes) = nodes.filter_map { it.body if it.is_a?(Prism::StatementsNode) }

  def wholes(nodes) = nodes.select { WHOLE.include?(it.class) }
end
