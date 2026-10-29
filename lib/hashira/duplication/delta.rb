# frozen_string_literal: true

class Hashira::Duplication::Delta
  def initialize(cluster)
    @cluster = cluster
  end

  def kind
    return :convention if @cluster.form.convention?
    return :identical if variances.empty?
    return :structure if variances.include?(:structure)
    return :renamed if inner.empty?
    renamed? ? :"renamed_#{body}" : body
  end

  def to_h
    { mass: @cluster.mass, sites: @cluster.count, kind: }.merge(locations: @cluster.sort_by(&:rank).map(&:range))
  end

  private

  def renamed? = variances.include?(:renamed)

  def body = inner.one? ? inner.fetch(0) : :mixed

  def inner = variances - [:renamed]

  def variances = @_variances ||= @cluster.variances.flat_map(&:kinds).uniq
end
