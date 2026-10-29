# frozen_string_literal: true

class Evaluation::Tally
  Z = 1.96

  def initialize(population:, sampled:, labeled:, positive:)
    @population = population
    @sampled = sampled
    @labeled = labeled
    @positive = positive
  end

  def to_h = { "population" => @population, "sampled" => @sampled, "labeled" => @labeled }.merge(judged)

  private

  def judged = @labeled.zero? ? { "tp" => 0, "precision" => nil } : { "tp" => @positive }.merge(bounds)

  def share = @positive.fdiv(@labeled)

  def bounds
    { "precision" => share.round(3), "low" => (middle - spread).round(3), "high" => (middle + spread).round(3) }
  end

  def shrink = 1 + ((Z**2) / @labeled)

  def middle = (share + ((Z**2) / (2 * @labeled))) / shrink

  def spread = Z * Math.sqrt((share * (1 - share) / @labeled) + ((Z**2) / (4 * (@labeled**2)))) / shrink
end
