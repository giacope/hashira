# frozen_string_literal: true

class Hashira::Complexity::Increment
  def initialize(line, cost, label)
    @line = line
    @cost = cost
    @label = label
  end

  def to_a = [@label, @line, @cost]
end
