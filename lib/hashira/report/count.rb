# frozen_string_literal: true

class Hashira::Report::Count
  def initialize(number, noun)
    @number = number
    @noun = noun
  end

  def to_s = "#{number} #{number == 1 ? noun : "#{noun}s"}"

  private

  attr_reader :number, :noun
end
