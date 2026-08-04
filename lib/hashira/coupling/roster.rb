# frozen_string_literal: true

class Hashira::Coupling::Roster
  def initialize(placed)
    @registry = Hashira::Coupling::ConstantRegistry.new
    @types = Hash.new(0)
    @typed = Set.new
    counted = Set.new
    placed.each { |definition, package| admit(definition, package, counted) }
  end

  attr_reader :registry, :types

  def origins = @registry.origins

  def type?(path) = @typed.include?(path)

  def packages = @types.keys | @registry.packages

  private

  def admit(definition, package, counted)
    return unless package
    path = definition.path
    @registry.register(path, package)
    @typed << path if definition.type?
    @types[package] += 1 if definition.counted? && counted.add?(path)
  end
end
