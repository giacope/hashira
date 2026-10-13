# frozen_string_literal: true

module Hashira
  module Coupling
    Shift =
      Data.define(:order, :from, :pairs) do
        def best = [*rightward, *leftward].min

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
      end
  end
end
