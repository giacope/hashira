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
    sized = sets.clusters.flat_map { admitted(it) }
    Hashira::Duplication::Maximal.new(sized.reject { relay?(it) }, BASE_MASS).reduced.reject { inverse?(it) }.sort_by { -it.mass }
  end

  private

  def relay?(cluster) = Hashira::Duplication::Relay.new(cluster, defined).relay?

  def inverse?(cluster)
    Hashira::Duplication::Inverse.new(cluster, @_filed ||= definitions.group_by { it.span.to_a.first }).inverse?
  end

  def defined = @_defined ||= definitions.to_set { it.to_a.first.name }

  def definitions = @_definitions ||= @all.select { it.to_a in [Prism::DefNode] }

  def sets
    fragments = @all.reject { it.shape.mass < BASE_MASS || it.body.schema? }
    shaped = fragments.group_by { it.shape.to_a }.each_value.flat_map { it.each_cons(2).to_a }
    Hashira::Duplication::UnionFind.new(shaped + Hashira::Duplication::NearMiss.new(fragments).pairs)
  end

  def admitted(group)
    whole = Hashira::Duplication::Grouping.new(group).cluster
    return [whole] if fits?(whole)
    group.group_by { it.shape.to_a }.values.map { Hashira::Duplication::Grouping.new(it).cluster }.select { fits?(it) }
  end

  def fits?(cluster)
    form = cluster.form
    base = !form.uniform? || form.structural? ? NEAR_MASS : BASE_MASS
    recurrences = form.convention? ? 0 : [cluster.count - PAIR, 0].max
    cluster.mass >= base + (recurrences * PENALTY_PER_RECURRENCE)
  end
end
