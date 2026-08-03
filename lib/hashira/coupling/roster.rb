# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @registry = Hashira::Coupling::ConstantRegistry.new
    @types = Hash.new(0)
    counted = Set.new
    placed.each { |definition, package| admit(definition, package, counted) }
  end

  attr_reader :registry, :types

  def origins = @registry.origins

  def packages = @types.keys | @registry.packages

  private

  def admit(definition, package, counted)
    return unless package
    path = definition.path
    @registry.register(path, package)
    @types[package] += 1 if definition.counted? && counted.add?(path)
  end
end
