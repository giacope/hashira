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
    Hashira::Duplication::Maximal.new(sized).reduced.reject { excused?(it) }.sort_by { -it.mass }
  end

  private

  def excused?(cluster) = relay?(cluster) || Hashira::Duplication::Inverse.new(cluster, definitions).inverse?

  def relay?(cluster) = Hashira::Duplication::Relay.new(cluster, defined).relay?

  def defined = @_defined ||= definitions.to_set { it.roots.first.name }

  def definitions = @_definitions ||= @all.select { it.roots in [Prism::DefNode] }

  def fragments = @_fragments ||= @all.select { |fragment| fragment.mass >= PREFILTER }.reject(&:schema?)

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

  def thin?(cluster) = !cluster.uniform? || cluster.structural?

  def penalty(cluster) = recurrences(cluster) * PENALTY_PER_RECURRENCE

  def recurrences(cluster) = [cluster.size - PAIR, 0].max
end
