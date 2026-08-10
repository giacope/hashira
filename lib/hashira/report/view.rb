# frozen_string_literal: true

module Hashira
  module Report
    View =
      Data.define(:project, :graph, :complexity, :duplication, :hotspots, :findings, :top, :compact) do
        def initialize(top: nil, compact: nil, **) = super
      end
  end
end
