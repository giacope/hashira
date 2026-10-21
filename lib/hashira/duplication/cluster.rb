# frozen_string_literal: true

module Hashira
  module Duplication
    CONVENTION = 10

    class Cluster
      def initialize(sites)
        @sites = sites
      end

      attr_reader :sites

      def canonical
        @_canonical ||= sites.map(&:types).tally.then { |shapes| sites.max_by { [shapes[it.types], it.mass] } }
      end

      def others = @_others ||= sites.reject { it.equal?(canonical) }

      def mass = canonical.mass

      def size = sites.size

      def structural? = (@_structural ||= [others.all? { Variance.new(canonical, it).structural? }]).first

      def uniform? = sites.map(&:types).uniq.one?

      def convention? = size >= CONVENTION && uniform? && !structural?
    end
  end
end
