# frozen_string_literal: true

module Hashira
  module Analysis
    Mark =
      Data.define(:magnitude, :trace) do
        def +(other) = with(magnitude: [magnitude, other.magnitude].compact.max)
      end
  end
end
