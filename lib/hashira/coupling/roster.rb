# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @placed = placed
  end

  def registry
    @_registry ||= Hashira::Coupling::ConstantRegistry.new(claims)
  end

  def types
    @_types ||= Hash.new(0).merge(admitted.select { it.first.counted? }.uniq { it.first.path }.map(&:last).tally)
  end

  def origins = registry.origins

  def type?(path) = typed.include?(path)

  def packages = types.keys | registry.packages

  private

  def claims = admitted.map { |definition, package| [definition.path, package] }

  def admitted = @_admitted ||= @placed.select(&:last)

  def typed
    @_typed ||= admitted.filter_map { |definition, _| definition.path if definition.type? }.to_set
  end
end
