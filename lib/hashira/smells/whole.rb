# frozen_string_literal: true

require "prism"

module Hashira
  module Smells
    class Footprint
      def initialize(openings)
        @openings = openings
      end

      def site = home.seat.at

      def shape = Shape.new(@openings.flat_map { it.accept(Imprint).to_a })

      private

      def home = @openings.find { it.seat.named? } || largest

      def largest = @openings.max_by { it.accept(Hashira::Analysis::Syntax::Body).to_a.compact.size }
    end

    class Bulk
      def initialize(openings)
        @openings = openings
      end

      def sweep = @openings.flat_map { it.accept(Scope).sweep }

      def statements = @openings.flat_map { it.accept(Hashira::Analysis::Syntax::Body).to_a }.compact

      def legible? = sweep.none? { Opaque.new([it]).any? }

      def singular? = statements.grep(Prism::CallNode).any? { extends_self?(it) }

      private

      def extends_self?(call) = call.name == :extend && Array(call.arguments&.arguments).any?(Prism::SelfNode)
    end

    class Whole
      include Enumerable

      def initialize(openings)
        @openings = openings
      end

      def to_s = first.to_s

      def each(&) = @openings.each(&)

      def spot = Footprint.new(@openings)

      def lot = first.lot

      def bulk = Bulk.new(@openings)

      def claimed? = @openings.any? { it.seat.claimed? }
    end
  end
end
