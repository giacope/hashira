# frozen_string_literal: true

class Evaluation::Draw
  def self.build(seeds) = new(seeds.map { "#{it}|" }.join)

  def initialize(salt, shelves = Evaluation::Shelves.new)
    @salt = salt
    @shelves = shelves
  end

  def labels = Evaluation::Labels.new(@shelves.labels(seed))

  def pending = @shelves.pending(seed)

  def pick(sightings, size)
    known = seen
    sightings.reject { known.include?(it.key) }.sort_by { rank(it) }.first(size)
  end

  private

  def seed = @salt.delete_suffix("|")

  def seen = @salt.empty? ? Set.new : [*known, *drawn].to_set

  def known = [@shelves.labels(""), *@shelves.raters].flat_map { Evaluation::Labels.new(it).entries.keys }

  def drawn = earlier.flat_map { Evaluation::Labels.new(it).listed }.map { it["key"] }

  def earlier = @shelves.drawn.reject { File.basename(it) == seed }

  def rank(sighting) = Digest::SHA256.hexdigest("#{@salt}#{sighting.key}")
end
