# frozen_string_literal: true

class Hashira::Duplication::Clusters
  PREFILTER = 12
  BASE_MASS = 16
  NEAR_MASS = 40
  PAIR = 2
  PENALTY_PER_RECURRENCE = 2

  def initialize(all)
    @all = all
  end

  def sorted
    fragments.group_by(&:types).each_value { |group| chain(group) }
    Hashira::Duplication::NearMiss.new(fragments).pairs.each { |left, right| sets.union(left, right) }
    Hashira::Duplication::Maximal.new(sized).reduced.sort_by { -it.mass }
  end

  private

  def fragments = @fragments ||= @all.select { |fragment| fragment.mass >= PREFILTER }

  def sets = @sets ||= Hashira::Duplication::UnionFind.new

  def chain(group) = group.each_cons(2) { |left, right| sets.union(left, right) }

  def sized = built.filter_map { admitted(it) }

  def admitted(cluster) = [cluster, core(cluster)].compact.find { fits?(it) }

  def fits?(cluster) = cluster.mass >= floor(cluster)

  def core(cluster) = Hashira::Duplication::Grouping.new(cluster.identical).cluster

  def built = sets.clusters.filter_map { |group| Hashira::Duplication::Grouping.new(group).cluster }

  def floor(cluster) = base(cluster) + penalty(cluster)

  def base(cluster) = thin?(cluster) ? NEAR_MASS : BASE_MASS

  def thin?(cluster) = !uniform?(cluster) || cluster.structural?

  def penalty(cluster) = recurrences(cluster) * PENALTY_PER_RECURRENCE

  def recurrences(cluster) = [cluster.size - PAIR, 0].max

  def uniform?(cluster) = cluster.sites.map(&:types).uniq.size == 1
end
