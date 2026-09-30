# frozen_string_literal: true

require "prism"

class Hashira::Duplication::Harvest
  WHOLE = [Prism::DefNode, Prism::WhenNode, Prism::RescueNode].freeze

  def initialize(project, trees)
    @project = project
    @trees = trees
  end

  def fragments = @_fragments ||= @trees.flat_map { |path, tree| scan(@project.relative(path), tree) }

  private

  def scan(relative, tree)
    nodes = Hashira::Analysis::NodeWalk.collect(tree)
    walks = Hashira::Duplication::Walks.new
    windows(relative, nodes, walks) + wholes(nodes).map { Hashira::Duplication::Fragment.new(relative, [it], walks) }
  end

  def windows(relative, nodes, walks)
    runs(nodes).flat_map { Hashira::Duplication::Sequence.new(relative, it, walks).fragments }
  end

  def runs(nodes) = nodes.filter_map { it.body if it.is_a?(Prism::StatementsNode) }

  def wholes(nodes) = nodes.select { WHOLE.include?(it.class) }
end
