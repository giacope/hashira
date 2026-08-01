# frozen_string_literal: true

class Hashira::Complexity::Rollup
  def initialize(scores)
    @scores = scores
  end

  def classes = @scores.group_by { owner(it.subject) }.map { |name, group| score(name, group) }

  private

  def score(name, group)
    Hashira::Complexity::ClassScore.new(
      name:, cognitive: group.sum(&:cognitive), method_count: group.size,
      peak: group.map(&:cognitive).max
    )
  end

  def owner(subject) = subject.split(/[#.]/, 2).first
end
