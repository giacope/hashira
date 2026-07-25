# frozen_string_literal: true

require "prism"

module Hashira
  module Duplication
    class Extractor
      WHOLE = [Prism::DefNode, Prism::WhenNode, Prism::RescueNode].freeze

      def initialize(project, trees)
        @project = project
        @fragments = trees.flat_map { |path, tree| from_tree(@project.relative(path), tree) }
      end

      attr_reader :fragments

      private

      def from_tree(rel, tree)
        nodes = Analysis::NodeWalk.collect(tree)
        windows(rel, nodes) + wholes(nodes).map { Fragment.new(rel, [it]) }
      end

      def windows(rel, nodes) = runs(nodes).flat_map { Sequence.new(rel, it).fragments }

      def runs(nodes) = nodes.filter_map { it.body if it.is_a?(Prism::StatementsNode) }

      def wholes(nodes) = nodes.select { WHOLE.include?(it.class) }
    end
  end
end
