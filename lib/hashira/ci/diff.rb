# frozen_string_literal: true

module Hashira
  module CI
    Diff =
      Data.define(:added, :removed, :worsened) do
        def self.between(current, recorded)
          new(
            added: current.keys - recorded.keys, removed: recorded.keys - current.keys,
            worsened: grown(current, recorded)
          )
        end

        def self.grown(current, recorded)
          (current.keys & recorded.keys).filter_map { entry(it, recorded[it], current[it]) }
        end

        def self.entry(key, before, after)
          [key, before, after] if before.is_a?(Integer) && after.is_a?(Integer) && after > before
        end

        def initialize(worsened: [], **) = super
        def empty? = added.empty? && removed.empty? && worsened.empty?
        def worse? = !added.empty? || !worsened.empty?
      end
  end
end
