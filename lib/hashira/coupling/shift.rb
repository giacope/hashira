# frozen_string_literal: true

module Hashira
  module Coupling
    class Shift
      def initialize(order:, from:, pairs:)
        @order = order
        @from = from
        @pairs = pairs
      end

      def best = [*rightward, *leftward].min(1).fetch(0)

      private

      def rightward = scanned(((from + 1)...order.size).to_a) { |node, other| [node, other] }

      def leftward = scanned((0...from).to_a.reverse) { |node, other| [other, node] }

      def scanned(slots)
        delta = 0
        slots.map do |slot|
          delta += flipped(*yield(order[from], order[slot]))
          [delta, from, slot]
        end
      end

      def flipped(ahead, behind) = pairs.fetch([ahead, behind], 0) - pairs.fetch([behind, ahead], 0)

      attr_reader :order, :from, :pairs
    end
  end
end
