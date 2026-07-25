# frozen_string_literal: true

module Hashira
  module Analysis
    Finding = Data.define(:kind, :package, :message, :evidence, :cycle, :digest) do
      def initialize(cycle: nil, digest: nil, **rest) = super

      def signature = "#{kind}:#{identity}"

      def identity = digest || package

      def to_h = super.compact
    end
  end
end
