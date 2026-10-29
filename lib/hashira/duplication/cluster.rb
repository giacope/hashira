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
        @_canonical ||= @sites.map { it.shape.to_a }.tally.then { |shapes| @sites.max_by { shaped(it, shapes) } }
      end

      def variances = others.map { Variance.new(canonical, it) }

      def mass = canonical.shape.mass

      def form = Form.new(@sites.map { it.shape.to_a }.uniq.one?, structural?, @sites.size)

      private

      def shaped(site, shapes)
        shape = site.shape
        [shapes[shape.to_a], shape.mass]
      end

      def others = @_others ||= @sites.reject { it.equal?(canonical) }

      def structural? = (@_structural ||= [variances.all?(&:structural?)]).first
    end
  end
end
