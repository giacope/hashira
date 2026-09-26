# frozen_string_literal: true

class Hashira::Duplication::Clusters
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

  def fragments = @_fragments ||= @all.select { |fragment| fragment.mass >= BASE_MASS }.reject(&:schema?)

  def sets = @_sets ||= Hashira::Duplication::UnionFind.new

  def chain(group) = group.each_cons(2) { |left, right| sets.union(left, right) }

  def sized = sets.clusters.flat_map { admitted(it) }

  def admitted(group)
    whole = Hashira::Duplication::Grouping.new(group).cluster
    whole && fits?(whole) ? [whole] : cores(group)
  end

  def cores(group) = shaped(group).select { fits?(it) }

  def shaped(group) = group.group_by(&:types).values.filter_map { Hashira::Duplication::Grouping.new(it).cluster }

  def fits?(cluster) = cluster.mass >= floor(cluster)

  def floor(cluster) = base(cluster) + penalty(cluster)

  def base(cluster) = thin?(cluster) ? NEAR_MASS : BASE_MASS

  def thin?(cluster) = !uniform?(cluster) || cluster.structural?

  def penalty(cluster) = recurrences(cluster) * PENALTY_PER_RECURRENCE

  def recurrences(cluster) = [cluster.size - PAIR, 0].max

  def uniform?(cluster) = cluster.sites.map(&:types).uniq.size == 1
end
