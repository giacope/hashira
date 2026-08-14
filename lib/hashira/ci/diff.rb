# frozen_string_literal: true

module Hashira
  module CI
    Diff =
      Data.define(:added, :removed, :worsened) do
        def initialize(worsened: [], **) = super
        def empty? = added.empty? && removed.empty? && worsened.empty?
        def worse? = !added.empty? || !worsened.empty?
      end
  end
end
