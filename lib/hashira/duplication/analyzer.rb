# frozen_string_literal: true

module Hashira
  module Duplication
    class Analyzer
      def initialize(project, trees, churn)
        @project = project
        @trees = trees
        @churn = churn
      end

      def clusters = @clusters ||= Clusterer.new(fragments).clusters.sort_by { -it.mass }

      def findings = clusters.map { |cluster| DuplicationFinding.new(cluster, @churn).to_finding }

      private

      def fragments = Extractor.new(@project, @trees).fragments
    end
  end
end
