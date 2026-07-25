# frozen_string_literal: true

module Hashira
  module Duplication
    class Similarity
      def initialize(left, right)
        @left = left
        @right = right
      end

      def ratio
        return 0.0 if @left.empty? || @right.empty?

        normalized(lcs)
      end

      def at_least?(threshold) = upper_bound >= threshold && ratio >= threshold

      private

      def upper_bound = normalized(tokens_in_common)

      def normalized(length) = (2.0 * length) / (@left.size + @right.size)

      def tokens_in_common
        counts = @right.tally
        @left.count { taken?(counts, it) }
      end

      def taken?(counts, token)
        return false unless counts.fetch(token, 0).positive?

        counts[token] -= 1
        true
      end

      def lcs = @left.reduce(blank) { |prev, token| next_row(prev, token) }.last

      def blank = Array.new(@right.size + 1, 0)

      def next_row(prev, token)
        @right.each_index.reduce([0]) { |row, index| row << cell(prev, row, token, index) }
      end

      def cell(prev, row, token, index)
        @right[index] == token ? prev[index] + 1 : [prev[index + 1], row[index]].max
      end
    end
  end
end
