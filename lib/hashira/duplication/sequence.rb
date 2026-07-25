# frozen_string_literal: true

module Hashira
  module Duplication
    class Sequence
      MIN_STATEMENTS = 1
      MAX_STATEMENTS = 12
      LIST_RUN = 3

      def initialize(file, statements)
        @file = file
        @statements = statements
      end

      def fragments = windows.reject { listed?(it) }.map { fragment(statements_in(it)) }

      private

      def windows = lengths.flat_map { |length| slide(length) }

      def lengths = MIN_STATEMENTS..[@statements.size, MAX_STATEMENTS].min

      def slide(length) = (0..(@statements.size - length)).map { it...(it + length) }

      def statements_in(window) = @statements.values_at(*window)

      def listed?(window) = listings.any? { |listing| listing.cover?(window) }

      def listings = @listings ||= same_shape_runs.select { |run| run.size >= LIST_RUN }

      def same_shape_runs = shape_changes.map { it.first...(it.last + 1) }

      def shape_changes = positions.slice_when { |left, right| shapes[left] != shapes[right] }

      def positions = 0...@statements.size

      def shapes = @shapes ||= @statements.map { fragment([it]).types }

      def fragment(roots) = Fragment.new(@file, roots)
    end
  end
end
