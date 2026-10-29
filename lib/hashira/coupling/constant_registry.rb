# frozen_string_literal: true

class Hashira::Coupling::ConstantRegistry
  AMBIGUOUS = Object.new.freeze

  private_constant :AMBIGUOUS

  def initialize(claims)
    @claims = claims
  end

  def origins = @_origins ||= keyed.transform_values { settled(it) }

  def claimed?(path) = origins[path.join("::")]

  def owner(path) = origins[path.join("::")].then { it unless it.equal?(AMBIGUOUS) }

  def packages = (origins.values.uniq - [AMBIGUOUS])

  private

  def keyed = @claims.reject { |path, _| path.empty? }.group_by { |path, _| path.join("::") }

  def settled(claims)
    packages = claims.map(&:last).uniq
    packages.one? ? packages.fetch(0) : AMBIGUOUS
  end
end
