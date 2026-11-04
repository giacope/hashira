# frozen_string_literal: true

class Hashira::Complexity::ClassScore
  def initialize(name, scores)
    @name = name
    @scores = scores
  end

  def cognitive = @scores.sum(&:cognitive)

  def to_h = { name: @name, cognitive:, method_count: @scores.size, peak: @scores.map(&:cognitive).max }

  def to_a = to_h.values
end
