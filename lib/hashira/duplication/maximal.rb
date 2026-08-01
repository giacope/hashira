# frozen_string_literal: true

class Hashira::Duplication::Maximal
  def initialize(clusters)
    @clusters = clusters
  end

  def reduced
    @clusters.sort_by { -it.mass }.each_with_object([]) do |cluster, kept|
      kept << cluster unless within?(cluster, kept.flat_map(&:sites))
    end
  end

  private

  def within?(cluster, bigger) = cluster.sites.all? { it.touches?(bigger) }
end
