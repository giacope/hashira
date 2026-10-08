# frozen_string_literal: true

module Hashira
  module Coupling
    Metric =
      Data.define(:types, :afferent, :efferent) do
        def instability
          total = efferent + afferent
          total.zero? ? 0.0 : efferent.fdiv(total)
        end

        def degree = efferent + afferent

        def isolated? = degree.zero?

        def order = [isolated? ? 1 : 0, instability]

        def to_h = counts.merge(i: (instability unless isolated?))

        def counts = { tc: types, ca: afferent, ce: efferent }

        def shown = format("%.2f", instability)

        def level = shown.to_f

        def cells = [types, afferent, efferent, isolated? ? "—" : shown]
      end
  end
end
