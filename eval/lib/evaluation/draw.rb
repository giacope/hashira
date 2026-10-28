# frozen_string_literal: true

module Evaluation
  Draw =
    Data.define(:salt, :shelves) do
      def initialize(shelves: Shelves.new, **) = super

      def self.build(seed) = seed ? new(salt: "#{seed}|") : new(salt: "")

      def labels = Labels.new(shelves.labels(seed))

      def seed = salt.delete_suffix("|")

      def pending = shelves.pending(seed)

      def pick(sightings, size)
        known = seen
        sightings.reject { known.include?(it.key) }.sort_by { rank(it) }.first(size)
      end

      def seen = salt.empty? ? Set.new : [*known, *drawn].to_set

      def known = [shelves.labels(""), *shelves.raters].flat_map { Labels.new(it).entries.keys }

      def drawn = earlier.flat_map { Labels.new(it).listed }.map { it["key"] }

      def earlier = shelves.drawn.reject { File.basename(it) == seed }

      def rank(sighting) = Digest::SHA256.hexdigest("#{salt}#{sighting.key}")
    end
end
