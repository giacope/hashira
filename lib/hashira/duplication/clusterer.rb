# frozen_string_literal: true

module Hashira
  module Duplication
    class Clusterer
      PREFILTER = 12
      BASE_MASS = 16
      NEAR_MASS = 40
      PAIR = 2
      PENALTY_PER_RECURRENCE = 2

      def initialize(fragments)
        @fragments = fragments.select { |fragment| fragment.mass >= PREFILTER }
        @sets = UnionFind.new
      end

      def clusters
        @fragments.group_by(&:types).each_value { |group| chain(group) }
        NearMiss.new(@fragments).pairs.each { |left, right| @sets.union(left, right) }
        Maximal.new(sized).reduced
      end

      private

      def chain(group) = group.each_cons(2) { |left, right| @sets.union(left, right) }

      def sized = built.filter_map { admitted(it) }

      def admitted(cluster) = [cluster, exact_core(cluster)].compact.find { fits?(it) }

      def fits?(cluster) = cluster.mass >= floor(cluster)

      def exact_core(cluster) = Grouping.new(cluster.exact_sites).cluster

      def built = @sets.clusters.filter_map { |group| Grouping.new(group).cluster }

      def floor(cluster) = base(cluster) + idiom_penalty(cluster)

      def base(cluster) = thin_evidence?(cluster) ? NEAR_MASS : BASE_MASS

      def thin_evidence?(cluster) = !one_shape?(cluster) || cluster.shape_only?

      def idiom_penalty(cluster) = recurrences(cluster) * PENALTY_PER_RECURRENCE

      def recurrences(cluster) = [cluster.size - PAIR, 0].max

      def one_shape?(cluster) = cluster.sites.map(&:types).uniq.size == 1
    end
  end
end
