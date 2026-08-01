# frozen_string_literal: true

module Hashira
  module Analysis
    Metric =
      Data.define(:types, :afferent, :efferent) do
        def instability
          total = efferent + afferent
          total.zero? ? 0.0 : efferent.fdiv(total)
        end

        def to_h = { tc: types, ca: afferent, ce: efferent, i: instability }
      end
  end
end
