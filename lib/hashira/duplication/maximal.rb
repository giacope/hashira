# frozen_string_literal: true

class Hashira::Duplication::Maximal
  FRESH = 2

  def initialize(clusters)
    @clusters = clusters
  end

  def reduced
    @clusters.sort_by { -it.mass }.each_with_object([]) do |cluster, kept|
      kept << cluster if news?(cluster.sites, kept.flat_map(&:sites))
    end
  end

  private

  def news?(sites, bigger) = !sites.all? { it.touches?(bigger) } && sites.count { !it.within?(bigger) } >= FRESH
end
