# frozen_string_literal: true

require "prism"

class Hashira::Smells::Tuples
  def initialize(types)
    @types = types
  end

  def bags = @types.flat_map { it.accept(Hashira::Smells::Bagging, it.to_s, it.seat, it.none?).to_a }
end
