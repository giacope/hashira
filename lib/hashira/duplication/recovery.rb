# frozen_string_literal: true

require "prism"

module Hashira
  module Duplication
    Recovery =
      Data.define(:clause) do
        def self.of(nodes) = nodes.grep(Prism::RescueNode).map { new(it) }.select(&:reporting?)

        def reporting? = lone.one? && Sink.new(lone.first, clause.reference&.name).sink?

        def lone = Array(clause.statements&.body)
      end
  end
end
