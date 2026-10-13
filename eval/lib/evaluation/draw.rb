# frozen_string_literal: true

module Evaluation
  Draw =
    Data.define(:salt, :seen) do
      def self.build(seed) = seed ? new(salt: "#{seed}|", seen: labelled) : Draw::DEV

      def self.labelled = Labels::DEV.flat_map { Labels.new(it).entries.keys }.to_set

      def labels = Labels.new(salt.empty? ? Labels::ROOT : File.join(Labels::ROOT, "holdout", seed))

      def seed = salt.delete_suffix("|")

      def pending = salt.empty? ? File.join(ROOT, "tmp", "pending") : File.join(ROOT, "tmp", "holdout", seed)

      def pick(sightings, size) = sightings.reject { seen.include?(it.key) }.sort_by { rank(it) }.first(size)

      def rank(sighting) = Digest::SHA256.hexdigest("#{salt}#{sighting.key}")
    end

  Draw::DEV = Draw.new(salt: "", seen: Set.new)
end
