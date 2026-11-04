# frozen_string_literal: true

require "prism"

module Hashira
  module Duplication
    class Recovery
      def self.of(nodes) = nodes.grep(Prism::RescueNode).select { new(it).reporting? }

      def initialize(clause)
        @clause = clause
      end

      def reporting? = lone.one? && Sink.new(lone.first, @clause.reference&.name).sink?

      private

      def lone = Array(@clause.statements&.body)
    end
  end
end
