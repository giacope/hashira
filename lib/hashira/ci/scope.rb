# frozen_string_literal: true

module Hashira
  module CI
    Scope =
      Data.define(:analyzers, :targets, :constraints) do
        def to_h = { analyzers: analyzers.map(&:to_s).sort, targets: targets.sort, constraints: constraints.sort }
      end
  end
end
