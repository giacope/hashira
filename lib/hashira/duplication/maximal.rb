# frozen_string_literal: true

module Hashira
  module Duplication
    class Maximal
      def initialize(clusters)
        @clusters = clusters
      end

      def reduced
        @clusters.sort_by { -it.mass }.each_with_object([]) do |cluster, kept|
          kept << cluster unless shadowed_by?(cluster, kept.flat_map(&:sites))
        end
      end

      private

      def shadowed_by?(cluster, bigger) = cluster.sites.all? { it.overlaps_any?(bigger) }
    end
  end
end
