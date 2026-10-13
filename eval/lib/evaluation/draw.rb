# frozen_string_literal: true

module Evaluation
  Draw =
    Data.define(:salt) do
      def self.build(seed) = seed ? new(salt: "#{seed}|") : Draw::DEV

      def labels = Labels.new(salt.empty? ? Labels::ROOT : File.join(Labels::ROOT, "holdout", seed))

      def seed = salt.delete_suffix("|")

      def pending = salt.empty? ? File.join(ROOT, "tmp", "pending") : File.join(ROOT, "tmp", "holdout", seed)

      def pick(sightings, size)
        known = seen
        sightings.reject { known.include?(it.key) }.sort_by { rank(it) }.first(size)
      end

      def seen = salt.empty? ? Set.new : Labels::DEV.flat_map { Labels.new(it).entries.keys }.to_set

      def rank(sighting) = Digest::SHA256.hexdigest("#{salt}#{sighting.key}")
    end

  Draw::DEV = Draw.new(salt: "")
end
