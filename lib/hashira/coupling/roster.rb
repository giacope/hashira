# frozen_string_literal: true

class Hashira::Coupling::Roster
  AMBIGUOUS = Object.new.freeze

  private_constant :AMBIGUOUS

  def initialize(placement, folding)
    @placement = placement
    @folding = folding
  end

  def to_a = to_h.keys | (origins.values.uniq - [AMBIGUOUS])

  def to_h
    @_to_h ||= Hash.new(0).merge(admitted.select { it.first.form.counted? }.uniq { it.first.to_a }.map(&:last).tally)
  end

  def type?(path) = typed.include?(path)

  def claimed?(path) = origins[path.join("::")]

  def owner(path) = origins[path.join("::")].then { it unless it.equal?(AMBIGUOUS) }

  def origins = @_origins ||= keyed.transform_values { settled(it) }

  private

  def admitted
    @_admitted ||= @placement.placed.map { |definition, package| [definition, translate(package)] }.select(&:last)
  end

  def translate(package) = @folding.map.fetch(package, package)

  def typed = @_typed ||= admitted.map(&:first).select { it.form.type? }.to_set(&:to_a)

  def keyed
    admitted.map { |definition, package| [definition.to_a, package] }.reject { |path, _| path.empty? }
      .group_by { |path, _| path.join("::") }
  end

  def settled(claims)
    packages = claims.map(&:last).uniq
    packages.one? ? packages.fetch(0) : AMBIGUOUS
  end
end
