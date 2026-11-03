# frozen_string_literal: true

require "digest"

class Hashira::Smells::Shape
  LENGTH = 12

  def initialize(marks)
    @marks = marks
  end

  def to_s = Digest::SHA256.hexdigest(@marks.inspect).slice(0, LENGTH)
end
