# frozen_string_literal: true

require "prism"

module Hashira
  module Duplication
    RECURRING = 3

    class Setting
      def self.of(body)
        names = body.body.grep(Prism::CallNode).reject(&:receiver).map(&:name).tally
        new(declarative: true, recurring: names.select { |_, count| count >= RECURRING }.keys)
      end

      def initialize(declarative:, recurring:)
        @declarative = declarative
        @recurring = recurring
      end

      def macros(nodes) = @declarative ? nodes.grep(Prism::CallNode).reject(&:receiver) : []

      def recurs?(name) = @recurring.include?(name)
    end
  end
end
