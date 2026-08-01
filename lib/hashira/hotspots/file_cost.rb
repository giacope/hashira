# frozen_string_literal: true

module Hashira
  module Hotspots
    CHURN_FLOOR = 1

    FileCost =
      Data.define(:file, :cognitive, :duplication, :churn) do
        def cost = cognitive + duplication

        def rank = cost * heat

        def heat = [churn, CHURN_FLOOR].max

        def to_h = { file:, cognitive:, duplication:, churn:, cost:, rank: }

        def cells = [file, cognitive, duplication, churn, rank]
      end
  end
end
