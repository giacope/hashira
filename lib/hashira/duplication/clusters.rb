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
    Hashira::Duplication::Maximal.new(sized.reject { relay?(it) }).reduced.reject { inverse?(it) }.sort_by { -it.mass }
  end

  private

  def relay?(cluster) = Hashira::Duplication::Relay.new(cluster, defined).relay?

  def inverse?(cluster)
    Hashira::Duplication::Inverse.new(cluster, @_filed ||= definitions.group_by(&:file)).inverse?
  end

  def defined = @_defined ||= definitions.to_set { it.roots.first.name }

  def definitions = @_definitions ||= @all.select { it.roots in [Prism::DefNode] }

  def fragments = @_fragments ||= @all.select { |fragment| fragment.mass >= PREFILTER }.reject(&:schema?)

  def sets
    shaped = fragments.group_by(&:types).each_value.flat_map { it.each_cons(2).to_a }
    @_sets ||= Hashira::Duplication::UnionFind.new(shaped + Hashira::Duplication::NearMiss.new(fragments).pairs)
  end

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

  def recurrences(cluster) = cluster.convention? ? 0 : [cluster.size - PAIR, 0].max
end
