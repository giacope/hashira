# frozen_string_literal: true

module Hashira
  module Duplication
    SHAPES = 0.8

    NAMES = 0.5

    class Pair
      def initialize(left, right)
        @left = left
        @right = right
      end

      def near? = !left.overlaps?(right) && named? && drifted?

      def drifted? = both(:types).uniq.size == 2 && close?(:counts, :types, SHAPES)

      def named? = words.any?(&:empty?) ? words.all?(&:empty?) : close?(:spoken, :vocabulary, NAMES)

      private

      def close?(tallies, sequences, floor)
        bound(*both(tallies)) >= floor && Similarity.new(*both(sequences)).ratio >= floor
      end

      def words = both(:vocabulary)

      def both(feature) = [left, right].map { it.public_send(feature) }

      def bound(one, two) = (2.0 * shared(one, two)) / (one.sum(&:last) + two.sum(&:last))

      def shared(one, two) = one.sum { |token, count| [count, two.fetch(token, 0)].min }

      attr_reader :left, :right
    end
  end
end
