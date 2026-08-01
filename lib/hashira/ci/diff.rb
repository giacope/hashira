# frozen_string_literal: true

module Hashira
  module CI
    Diff =
      Data.define(:added, :removed) do
        def self.between(current, recorded)
          new(added: current - recorded, removed: recorded - current)
        end

        def empty? = added.empty? && removed.empty?

        def worse? = !added.empty?
      end
  end
end
