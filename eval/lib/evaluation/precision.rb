# frozen_string_literal: true

class Evaluation::Precision
  def initialize(sightings, sizes, labels)
    @sightings = sightings
    @sizes = sizes
    @labels = labels
  end

  def summary = @sizes.to_h { |kind, size| [kind, tally(kind, sampled(kind, size)).to_h] }

  def pending = @sizes.flat_map { |kind, size| sampled(kind, size).reject { @labels.verdict(it.key) } }

  private

  def sampled(kind, size) = Evaluation::Sample.new(@sightings.select { it.kind == kind }, size).to_a

  def tally(kind, picked)
    verdicts = picked.filter_map { @labels.verdict(it.key) }
    population = @sightings.count { it.kind == kind }
    Evaluation::Tally.new(population:, sampled: picked.size, labeled: verdicts.size, positive: verdicts.count("tp"))
  end
end
