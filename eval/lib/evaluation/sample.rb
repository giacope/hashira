# frozen_string_literal: true

class Evaluation::Sample
  def initialize(sightings, size)
    @sightings = sightings
    @size = size
  end

  def to_a = @sightings.sort_by(&:rank).first(@size)
end
