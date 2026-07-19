# frozen_string_literal: true

module Hashira
  module Analysis
    Edge = Data.define(:from, :to) do
      def to_s = "#{from} -> #{to}"
    end
  end
end
