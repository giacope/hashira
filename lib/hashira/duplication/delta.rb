# frozen_string_literal: true

class Hashira::Duplication::Delta
  def initialize(cluster)
    @cluster = cluster
  end

  def kind
    tags = kinds
    tags.empty? ? :identical : label(tags)
  end

  def to_h
    { mass: @cluster.mass, sites: @cluster.size, kind: }.merge(locations: @cluster.sites.sort_by(&:rank).map(&:range))
  end

  private

  def label(tags)
    return :structure if tags.include?(:structure)
    tags.size == 1 ? tags.first : :mixed
  end

  def kinds = inner.empty? ? variances : inner

  def inner = variances - [:renamed]

  def variances = @_variances ||= @cluster.others.flat_map { variance(it).kinds }.uniq

  def variance(other) = Hashira::Duplication::Variance.new(@cluster.canonical, other)
end
