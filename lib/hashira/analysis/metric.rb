# frozen_string_literal: true

module Hashira
  module Analysis
    Metric = Data.define(:type_count, :afferent, :efferent) do
      def instability
        total = efferent + afferent
        total.zero? ? 0.0 : efferent.to_f / total
      end

      def to_h = { tc: type_count, ca: afferent, ce: efferent, i: instability }
    end
  end
end
