# frozen_string_literal: true

module Hashira
  module Analysis
    Finding = Data.define(:kind, :package, :message, :evidence, :cycle) do
      def initialize(cycle: nil, **rest) = super

      def to_h = super.compact
    end
  end
end
