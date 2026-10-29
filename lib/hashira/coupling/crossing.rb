# frozen_string_literal: true

class Hashira::Coupling::Crossing
  def initialize(layers, to, said)
    @layers = layers
    @to = to
    @said = said
  end

  def to_a = @layers

  def to_s = @said.to_s

  def outward? = @layers.fetch(0) > @layers.fetch(1)

  def ends = @said.ends(@to)

  def evidence = @said.evidence
end
