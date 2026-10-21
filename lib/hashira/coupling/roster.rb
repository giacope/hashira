# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @placed = placed
  end

  def registry
    admitted
    @_registry
  end

  def types
    admitted
    @_types
  end

  def origins = registry.origins

  def type?(path) = typed.include?(path)

  def packages = types.keys | registry.packages

  private

  def admitted
    return if @_admitted
    @_admitted = true
    blank
    fill
  end

  def blank
    @_registry = Hashira::Coupling::ConstantRegistry.new
    @_types = Hash.new(0)
  end

  def typed
    @_typed ||= @placed.filter_map { |definition, package| definition.path if package && definition.type? }.to_set
  end

  def fill
    counted = Set.new
    @placed.each { |definition, package| admit(definition, package, counted) }
  end

  def admit(definition, package, counted)
    return unless package
    path = definition.path
    @_registry.register(path, package)
    @_types[package] += 1 if definition.counted? && counted.add?(path)
  end
end
