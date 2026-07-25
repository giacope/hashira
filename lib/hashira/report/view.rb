# frozen_string_literal: true

module Hashira
  module Report
    View = Data.define(:project, :graph, :complexity, :duplication, :hotspots, :findings)
  end
end
