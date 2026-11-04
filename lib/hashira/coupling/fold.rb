# frozen_string_literal: true

class Hashira::Coupling::Fold
  def initialize(from, to, via)
    @from = from
    @to = to
    @via = via
  end

  def to_h = { from: @from, to: @to, via: @via }

  def to_s = "#{@from} -> #{@to} (#{@via})"
end
