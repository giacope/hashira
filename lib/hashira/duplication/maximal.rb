# frozen_string_literal: true

class Hashira::Duplication::Maximal
  FRESH = 2

  def initialize(clusters, margin)
    @clusters = clusters
    @margin = margin
  end

  def reduced
    ordered.each_with_object([]) do |cluster, kept|
      kept << cluster if news?(cluster.sites, shadows(cluster, kept))
    end
  end

  private

  def ordered = @clusters.sort_by { [it.convention? ? -it.size : 0, -it.mass] }

  def shadows(cluster, kept) = kept.select { covers?(it, cluster) }.flat_map(&:sites)

  def covers?(bigger, cluster) = !bigger.convention? || cluster.mass < bigger.mass + @margin

  def news?(sites, bigger) = !sites.all? { it.touches?(bigger) } && sites.count { !it.within?(bigger) } >= FRESH
end
