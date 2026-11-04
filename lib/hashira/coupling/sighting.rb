# frozen_string_literal: true

class Hashira::Coupling::Sighting
  def initialize(file, from, path, said)
    @file = file
    @from = from
    @path = path
    @said = said
  end

  def to_a = @path

  def rank(layers) = layers.rank(@file, @from)

  def couples(code) = code.files(@path).map { [@file, it] }

  def trail(lookup) = [@path, *lookup.vias(@path)]

  def cross(source, target, to) = Hashira::Coupling::Crossing.new([source, target], to, @said)
end
