# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @placed = placed
  end

  def registry
    admitted
    @registry
  end

  def types
    admitted
    @types
  end

  def origins = registry.origins

  def type?(path)
    admitted
    @typed.include?(path)
  end

  def packages = types.keys | registry.packages

  private

  def admitted
    return if @admitted
    @admitted = true
    blank
    fill
  end

  def blank
    @registry = Hashira::Coupling::ConstantRegistry.new
    @types = Hash.new(0)
    @typed = Set.new
  end

  def fill
    counted = Set.new
    @placed.each { |definition, package| admit(definition, package, counted) }
  end

  def admit(definition, package, counted)
    return unless package
    path = definition.path
    @registry.register(path, package)
    @typed << path if definition.type?
    @types[package] += 1 if definition.counted? && counted.add?(path)
  end
end
