# frozen_string_literal: true

module Hashira
  module Report
    View =
      Data.define(:project, :files, :graph, :complexity, :duplication, :hotspots, :findings, :top, :compact) do
        def initialize(files: 0, top: nil, compact: nil, **) = super
      end
  end
end
