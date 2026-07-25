# frozen_string_literal: true

module Hashira
  module Complexity
    class Analyzer
      THRESHOLD = 10

      def initialize(project, trees)
        @project = project
        @scores = trees.flat_map { |path, tree| scores_for(path, tree) }
      end

      def methods = @scores.sort_by { -it.cognitive }

      def classes = Rollup.new(@scores).classes.sort_by { -it.cognitive }

      def findings = flagged.map { MethodFinding.new(it).to_finding }

      private

      def flagged = methods.select { it.cognitive >= THRESHOLD }

      def scores_for(path, tree)
        rel = @project.relative(path)
        methods_in(tree).map { |full, node| build_score(rel, full, node) }
      end

      def methods_in(tree)
        found = []
        Analysis::TypeWalk.each_definition(tree) do |type_node, full|
          Analysis::Syntax.direct_definitions(type_node).each { found << [full, it] }
        end
        found
      end

      def build_score(rel, full, node)
        score = CognitiveScore.new(node)
        MethodScore.new(subject: subject(full, node), file: rel, line: node.location.start_line,
                        cognitive: score.total, calls: score.calls, increments: score.increments)
      end

      def subject(full, node) = "#{full.join("::")}#{node.receiver ? "." : "#"}#{node.name}"
    end
  end
end
