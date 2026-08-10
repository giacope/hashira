# frozen_string_literal: true

module Hashira
  module CI
    Scope =
      Data.define(:analyzers, :targets) do
        def self.none = new(analyzers: [], targets: [])
        def to_h = { analyzers: analyzers.map(&:to_s).sort, targets: targets.sort }
      end
  end
end
