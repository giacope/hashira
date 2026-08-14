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

  def type?(path)
    admitted
    @_typed.include?(path)
  end

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
    @_typed = Set.new
  end

  def fill
    counted = Set.new
    @placed.each { |definition, package| admit(definition, package, counted) }
  end

  def admit(definition, package, counted)
    return unless package
    path = definition.path
    @_registry.register(path, package)
    @_typed << path if definition.type?
    @_types[package] += 1 if definition.counted? && counted.add?(path)
  end
end
