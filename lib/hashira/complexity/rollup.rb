# frozen_string_literal: true

class Hashira::Complexity::Rollup
  def initialize(scores)
    @scores = scores
  end

  def classes = @scores.group_by(&:owner).map { |name, group| Hashira::Complexity::ClassScore.new(name, group) }
end
