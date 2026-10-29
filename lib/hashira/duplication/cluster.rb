# frozen_string_literal: true

module Hashira
  module Duplication
    CONVENTION = 10

    class Cluster
      class Form
        def initialize(uniform, structural, size)
          @uniform = uniform
          @structural = structural
          @size = size
        end

        def uniform? = @uniform

        def structural? = @structural

        def convention? = @size >= CONVENTION && @uniform && !@structural
      end

      include Enumerable

      def initialize(sites)
        @sites = sites
      end

      def each(&) = @sites.each(&)

      def canonical
        @_canonical ||= @sites.map(&:types).tally.then { |shapes| @sites.max_by { [shapes[it.types], it.mass] } }
      end

      def variances = others.map { Variance.new(canonical, it) }

      def mass = canonical.mass

      def form = Form.new(@sites.map(&:types).uniq.one?, structural?, @sites.size)

      private

      def others = @_others ||= @sites.reject { it.equal?(canonical) }

      def structural? = (@_structural ||= [variances.all?(&:structural?)]).first
    end
  end
end
