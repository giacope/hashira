# frozen_string_literal: true

class Hashira::Report::Json::Complexity
  def initialize(scores)
    @scores = scores
  end

  def to_h(cap) = { complexity: lists.transform_values { cap.call(it).map(&:to_h) } }

  def lists = @scores.to_h
end
