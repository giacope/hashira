# frozen_string_literal: true

module Hashira
  module Report
    Unjudged =
      Data.define(:kinds, :depth, :judged) do
        def verdict
          return "none ✓ — structure is healthy" if kinds.empty?
          return "none — #{named} could not judge: #{reason}" unless judged
          "none ✓ for the kinds judged; #{named} not judged (#{reason})"
        end

        def to_a = kinds.map { { kind: it, reason: } }

        def reason = Hashira::Report::History.new(depth).to_s

        def named = kinds.join(", ")
      end

    Unjudged::NONE = Unjudged.new(kinds: [], depth: nil, judged: true)
  end
end
