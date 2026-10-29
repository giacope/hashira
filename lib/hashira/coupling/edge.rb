# frozen_string_literal: true

class Hashira::Coupling::Edge
  def initialize(from, to, map, tally)
    @from = from
    @to = to
    @map = map
    @tally = tally
  end

  def to_s = "#{@from} -> #{@to}"

  def to_a = [@from, @to, evidence.size]

  def evidence = @map[@from, @to].to_a

  def guarantees = @map.guarantees(@from, @to)

  def constants = @map.constants(@from, @to)

  def aside? = @tally.aside?(@from) || @tally.aside?(@to)
end
