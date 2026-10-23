# frozen_string_literal: true

module Hashira
  module Report
    View =
      Data.define(
        :project, :graph, :complexity, :duplication, :hotspots, :findings, :top, :compact, :screened, :unjudged
      ) do
        def initialize(top: nil, compact: nil, unjudged: Unjudged::NONE, **) = super

        def suppressed = screened.suppressed

        def label = project.label

        def size = project.files.size
      end
  end
end
