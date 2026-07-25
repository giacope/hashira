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

      def fragments
        return [] if listing?

        lengths.flat_map { |length| slide(length) }
      end

      private

      def listing? = @statements.size >= LIST_RUN && shapes.uniq.size == 1

      def shapes = @statements.map { fragment([it]).types }

      def lengths = MIN_STATEMENTS..[@statements.size, MAX_STATEMENTS].min

      def slide(length) = (0..(@statements.size - length)).map { fragment(@statements[it, length]) }

      def fragment(roots) = Fragment.new(@file, roots)
    end
  end
end
