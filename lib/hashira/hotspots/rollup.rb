# frozen_string_literal: true

class Hashira::Hotspots::Rollup
  def initialize(complexity, duplication, churn)
    @complexity = complexity
    @duplication = duplication
    @churn = churn
  end

  def weighed? = @churn.history?

  def files = costs.reject(&:idle?).sort

  private

  def costs = (cognitive.keys | duplicated.keys).map { cost(it) }

  def cost(file)
    Hashira::Hotspots::FileCost.new(file, cognitive[file], duplicated[file], @churn.hits(file))
  end

  def scores = @complexity.flat_map(&:ranked)

  def coverage = @duplication.flat_map { it.coverage.to_a }.to_h

  def cognitive = @_cognitive ||= bucketed(scores.map(&:charge))

  def duplicated = @_duplicated ||= Hash.new(0).merge(coverage)

  def bucketed(charges) = charges.each_with_object(Hash.new(0)) { |(file, cost), total| total[file] += cost }
end
