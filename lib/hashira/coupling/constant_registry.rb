# frozen_string_literal: true

class Hashira::Coupling::ConstantRegistry
  AMBIGUOUS = Object.new.freeze

  def initialize(claims)
    @claims = claims
  end

  def origins = @_origins ||= keyed.transform_values { settled(it) }

  def exact(path) = origins[path.join("::")]

  def packages = (origins.values.uniq - [AMBIGUOUS])

  private

  def keyed = @claims.reject { |path, _| path.empty? }.group_by { |path, _| path.join("::") }

  def settled(claims)
    packages = claims.map(&:last).uniq
    packages.one? ? packages.first : AMBIGUOUS
  end
end
