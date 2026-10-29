# frozen_string_literal: true

class Hashira::Hotspots::FileCost
  CHURN_FLOOR = 1

  def initialize(file, cognitive, duplication, churn)
    @file = file
    @cognitive = cognitive
    @duplication = duplication
    @churn = churn
  end

  def idle? = cost.zero?

  def <=>(other) = order <=> other.order

  def to_h = { file: @file, cognitive: @cognitive, duplication: @duplication, churn: @churn, cost:, rank: }

  def to_a = [@file, @cognitive, @duplication, @churn, rank]

  protected

  def order = [-rank, @file]

  private

  def cost = @cognitive + @duplication

  def rank = cost * [@churn, CHURN_FLOOR].max
end
