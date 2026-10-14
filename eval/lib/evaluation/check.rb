# frozen_string_literal: true

module Evaluation
  Check =
    Data.define(:suite, :name, :expected, :actual) do
      def self.of(suite, name, expected, actual) = new(suite:, name:, expected:, actual:)

      def passed? = expected == actual

      def row = { "name" => name, "passed" => passed? }.merge("expected" => expected, "actual" => actual)
    end

  SEEN = { true => :present, false => :absent }.freeze
end
