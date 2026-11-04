# frozen_string_literal: true

class Evaluation::Accord
  def initialize(pairs)
    @pairs = pairs
  end

  def empty? = @pairs.empty?

  def cells = [@pairs.size, agreed, kappa, positive(0), positive(1)]

  private

  def agreed = @pairs.count { |human, rater| human == rater }

  def kappa
    chance = %w[tp fp].sum { |verdict| share(0, verdict) * share(1, verdict) }
    chance == 1 ? "—" : ((agreed.fdiv(@pairs.size) - chance) / (1 - chance)).round(2)
  end

  def share(side, verdict) = @pairs.count { it[side] == verdict }.fdiv(@pairs.size)

  def positive(side) = @pairs.count { it[side] == "tp" }
end
