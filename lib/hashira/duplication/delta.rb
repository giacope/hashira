# frozen_string_literal: true

class Hashira::Duplication::Delta
  def initialize(cluster)
    @cluster = cluster
  end

  def kind
    return :convention if @cluster.convention?
    return :identical if variances.empty?
    return :structure if variances.include?(:structure)
    return :renamed if inner.empty?
    renamed? ? :"renamed_#{body}" : body
  end

  def to_h
    { mass: @cluster.mass, sites: @cluster.size, kind: }.merge(locations: @cluster.sites.sort_by(&:rank).map(&:range))
  end

  private

  def renamed? = variances.include?(:renamed)

  def body = inner.one? ? inner.first : :mixed

  def inner = variances - [:renamed]

  def variances = @_variances ||= @cluster.others.flat_map { variance(it).kinds }.uniq

  def variance(other) = Hashira::Duplication::Variance.new(@cluster.canonical, other)
end
