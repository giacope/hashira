# frozen_string_literal: true

class Hashira::Hotspots::Rollup
  def initialize(complexity, duplication, churn)
    @complexity = complexity
    @duplication = duplication
    @churn = churn
  end

  def files = costs.reject { it.cost.zero? }.sort_by { [-it.rank, it.file] }

  private

  def costs = (cognitive.keys | duplicated.keys).map { cost(it) }

  def cost(file)
    Hashira::Hotspots::FileCost.new(
      file:, cognitive: cognitive[file], duplication: duplicated[file], churn: @churn.hits(file)
    )
  end

  def scores = @complexity ? @complexity.ranked : []

  def clusters = @duplication ? @duplication.clusters : []

  def cognitive = @cognitive ||= bucketed(scores.map { [it.file, it.cognitive] })

  def duplicated = @duplicated ||= bucketed(clusters.flat_map(&:masses))

  def bucketed(charges) = charges.each_with_object(Hash.new(0)) { |(file, cost), total| total[file] += cost }
end
