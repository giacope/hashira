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

      def near? = !left.span.overlaps?(right.span) && named? && drifted?

      def drifted?
        shapes = both(:shape)
        shapes.map(&:to_a).uniq.size == 2 && close?(shapes, SHAPES)
      end

      def named? = words.any?(&:empty?) ? words.all?(&:empty?) : close?(both(:words), NAMES)

      private

      def close?(roles, floor)
        bound(*roles.map(&:to_h)) >= floor && Similarity.new(*roles.map(&:to_a)).ratio >= floor
      end

      def words = both(:words).map(&:to_a)

      def both(feature) = [left, right].map { it.public_send(feature) }

      def bound(one, two) = (2.0 * shared(one, two)) / (one.sum(&:last) + two.sum(&:last))

      def shared(one, two) = one.sum { |token, count| [count, two.fetch(token, 0)].min }

      attr_reader :left, :right
    end
  end
end
