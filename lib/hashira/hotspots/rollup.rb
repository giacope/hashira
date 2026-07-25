# frozen_string_literal: true

module Hashira
  module Hotspots
    class Rollup
      def initialize(complexity, duplication, churn)
        @complexity = complexity
        @duplication = duplication
        @churn = churn
      end

      def files = costs.reject { it.cost.zero? }.sort_by { [-it.rank, it.file] }

      private

      def costs = (cognitive.keys | duplicated.keys).map { cost_for(it) }

      def cost_for(file)
        FileCost.new(file:, cognitive: cognitive[file], duplication: duplicated[file], churn: @churn.hits(file))
      end

      def scores = @complexity ? @complexity.methods : []

      def clusters = @duplication ? @duplication.clusters : []

      def cognitive = @cognitive ||= per_file(scores.map { [it.file, it.cognitive] })

      def duplicated = @duplicated ||= per_file(clusters.flat_map(&:site_masses))

      def per_file(charges) = charges.each_with_object(Hash.new(0)) { |(file, cost), total| total[file] += cost }
    end
  end
end
