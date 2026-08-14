# frozen_string_literal: true

module Hashira
  module Coupling
    Metric =
      Data.define(:types, :afferent, :efferent) do
        def instability
          total = efferent + afferent
          total.zero? ? 0.0 : efferent.fdiv(total)
        end

        def isolated? = (efferent + afferent).zero?

        def order = [isolated? ? 1 : 0, instability]

        def to_h = counts.merge(i: (instability unless isolated?))

        def counts = { tc: types, ca: afferent, ce: efferent }

        def cells = [types, afferent, efferent, isolated? ? "—" : format("%.2f", instability)]
      end
  end
end
