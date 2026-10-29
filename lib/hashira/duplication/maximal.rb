# frozen_string_literal: true

class Hashira::Duplication::Maximal
  FRESH = 2

  def initialize(clusters, margin)
    @clusters = clusters
    @margin = margin
  end

  def reduced
    ordered.each_with_object([]) do |cluster, kept|
      kept << cluster if news?(cluster.to_a, shadows(cluster, kept))
    end
  end

  private

  def ordered = @clusters.sort_by { [it.form.convention? ? -it.count : 0, -it.mass] }

  def shadows(cluster, kept) = kept.select { covers?(it, cluster) }.flat_map(&:to_a)

  def covers?(bigger, cluster) = !bigger.form.convention? || cluster.mass < bigger.mass + @margin

  def news?(sites, bigger)
    spans = bigger.map(&:span)
    own = sites.map(&:span)
    return false if own.all? { |span| spans.any? { span.overlaps?(it) } }
    own.count { |span| spans.none? { span.inside?(it) } } >= FRESH
  end
end
